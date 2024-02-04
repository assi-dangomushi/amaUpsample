# Copyright (C) 2024 Amanogawa Audio Labo
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>.

# amaUpsample.nim version 0.0.1

# 44.1KHz を 48 96 192 384KHz にアップサンプリングする
# 標準入力から int32 で読み込み int32 で出力
# 入力データ数は 147 の倍数、とりあえず1470とする

import std/math
import std/complex
import fftw3_1d
import std/os
import std/strutils

# coefファイル読み込み 複素数版
proc readCoefC(coefFile: string): seq[Complex64] =
  var
    f: File
    l: int64
    coef: seq[Complex64]
    r: int
  if open(f, coefFile):
    defer: close f
    l = f.getFileSize
    coef.setlen(l div sizeof(Complex64))
    r = f.readBuffer(coef[0].addr, l*sizeof(float64))
    stderr.writeLine($coefFile & " length: "  & $coef.len)
    return coef
  else:
    stderr.writeLine($coefFile &  " is not exist!")
    quit(1)

# db計算
func db2mag*(x: float64): float64 = return pow(10, x / 20)

# avoid nasal demons low = low(int32)+1
proc i32*(x: float64): int32 =
  if x >= high(int32).float64:
    return high(int32)
  if x <= (low(int32)+1).float64:
    return low(int32)+1
  return x.round.int32

const
  WISDOM = "wisdom_amaUpsample"
  T:int  = 10 # 倍数
  N2 = 147 # N1/N2 にアップサンプリング
  Nin = N2*T # 読み込むサンプル数 1470

# 初期化
let
  vargs = commandLineParams()
  CoefName = vargs[0]
  targetFs = vargs[1].parseInt
  gain = vargs[2].parseFloat
  N1: int = max((targetFs * 147) div 44100, 320) # 48Kの場合も96Kで計算して最後に1/2にする
 
if targetFs notin [48000, 96000, 192000, 384000]:
    stderr.writeLine("Invalid targetFs!")
    quit(1)

let
  Nout = T * N1 # 96000 なら 3200
  nGain:float64 = db2mag(gain) / (Nout*2).float64 * N1.float64 / N2.float64 # fftw3 のノーマライズと サンプルレート変換のノーマライズ 
  # coefFft は fft 済の係数ファイル(複素数、長さ6400のうち、最初の2940(44085Hzまで)) サンプリング周波数は 96000Hz
  coefFft = readCoefC(CoefName)
var
  bufferIn: array[Nin, array[2, int32]]
  buffer1L: array[Nin*2, float64] # overlap-save のため、2倍確保
  buffer1R: array[Nin*2, float64] # overlap-save のため、2倍確保
  bufferFftL = newSeq[Complex64](Nout+1) # targetFsに合わせて確保
  bufferFftR = newSeq[Complex64](Nout+1) # targetFsに合わせて確保
  buffer2L = newSeq[float64](Nout*2) # overlap-save のため2倍、前半が有効な値
  buffer2R = newSeq[float64](Nout*2) # overlap-save のため2倍、前半が有効な値
  bufferOut = newSeq[array[2, int32]](Nout) # int32 2ch で出力 

# make plan
discard fftw_import_wisdom_from_filename(WISDOM)
var
  plan1L = fftw_plan_dft_r2c_1d((Nin*2).cint, cast[ptr cdouble](buffer1L.addr), cast[ptr Complex64](bufferFftL[0].addr), FFTW_EXHAUSTIVE)
  plan1R = fftw_plan_dft_r2c_1d((Nin*2).cint, cast[ptr cdouble](buffer1R.addr), cast[ptr Complex64](bufferFftR[0].addr), FFTW_EXHAUSTIVE)
  plan2L = fftw_plan_dft_c2r_1d((Nout*2).cint, cast[ptr Complex64](bufferFftL[0].addr), cast[ptr cdouble](buffer2L[0].addr), FFTW_EXHAUSTIVE)
  plan2R = fftw_plan_dft_c2r_1d((Nout*2).cint, cast[ptr Complex64](bufferFftR[0].addr), cast[ptr cdouble](buffer2R[0].addr), FFTW_EXHAUSTIVE)
discard fftw_export_wisdom_to_filename(WISDOM)

proc main() =
  var r:int
  while stdin.endOfFile.not:
    # N サンプル  2ch 読み込み
    r = stdin.readBuffer(bufferIn.addr, Nin * 2 * sizeof(int32))
    r = r div (2 * sizeof(int32)) # rをサンプル数にする
    # LR別にfloat64に変換、overlap-saveのため後半に入力  値は -1 - +1 に正規化
    for n in 0..<r:
      buffer1L[Nin+n] = bufferIn[n][0].float64 / 2147483648.0
      buffer1R[Nin+n] = bufferIn[n][1].float64 / 2147483648.0
    # fft forward (Nin*2) → (Nin+1)
    fftw_execute(plan1L)
    fftw_execute(plan1R)
    # add mirror image　(<44100Hz)
    for n in (Nin+1)..<(2*Nin):
      bufferFftL[n] = conjugate(bufferFftL[2*Nin - n])
      bufferFftR[n] = conjugate(bufferFftR[2*Nin - n])
    # conv coefFft (0 .. <2*N)
    for n in 0..<(2*Nin):
      bufferFftL[n] = bufferFftL[n] * coefFft[n]
      bufferFftR[n] = bufferFftR[n] * coefFft[n]
    # fft c2r
    fftw_execute(plan2L)
    fftw_execute(plan2R)
    # clear bufferFFt (fftw3_c2r destory bufferFft)
    for n in (2*Nin)..<(Nout+1):
      bufferFftL[n] = complex64(0.0, 0.0)
      bufferFftR[n] = complex64(0.0, 0.0)
    # shift buffer1 (overap-save)
    for n in 0..<Nin:
      buffer1L[n] = buffer1L[Nin + n]
      buffer1R[n] = buffer1R[Nin + n]
    # downsample 96K to 48K
    if targetFs == 48000:
      # copy to  bufferOut (cast to int32) 
      for n in 0..<(Nout div 2):
        bufferOut[n][0] = (buffer2L[n*2] * nGain * 2147483647).i32
        bufferOut[n][1] = (buffer2R[n*2] * nGain * 2147483647).i32
      r = r div 2 # 出力サンプル数を半分にする
    else: # 96 192 382KHz
      # copy to  bufferOut (cast to int32) 
      for n in 0..<Nout:
        bufferOut[n][0] = (buffer2L[n] * nGain * 2147483647).i32
        bufferOut[n][1] = (buffer2R[n] * nGain * 2147483647).i32
    # output
    discard stdout.writeBuffer(bufferOut[0].addr, ((r*N1) div N2) * 2 * sizeof(int32))

main()

