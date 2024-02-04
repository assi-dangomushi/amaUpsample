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

# This program is based https://github.com/ziotom78/nimfftw3/blob/master/fftw3.nim
# Only the part required for audio processing was taken out of the original.

# fftw3_1d.nim version 0.1

import complex

const LibraryName = "libfftw3.so"

const
    FFTW_MEASURE* = 0
    FFTW_DESTROY_INPUT* = 1
    FFTW_UNALIGNED* = 1 shl 1
    FFTW_CONSERVE_MEMORY* = 1 shl 2
    FFTW_EXHAUSTIVE* = 1 shl 3
    FFTW_PRESERVE_INPUT* = 1 shl 4
    FFTW_PATIENT* = 1 shl 5
    FFTW_ESTIMATE* = 1 shl 6
    FFTW_WISDOM_ONLY* = 1 shl 21
    FFTW_FORWARD* = -1
    FFTW_BACKWARD* = 1

type
  #fftw_complex* = array[2, cdouble]
  fftw_plan* = pointer

proc fftw_execute*(p: fftw_plan) {.cdecl, importc: "fftw_execute", dynlib: LibraryName.}

proc fftw_plan_dft_r2c_1d*(n: cint; `in`: ptr cdouble; `out`: ptr Complex64; flags: cuint): fftw_plan {.cdecl, importc: "fftw_plan_dft_r2c_1d", dynlib: LibraryName.}

proc fftw_plan_dft_c2r_1d*(n: cint; `in`: ptr Complex64; `out`: ptr cdouble; flags: cuint): fftw_plan {.cdecl, importc: "fftw_plan_dft_c2r_1d", dynlib: LibraryName.}

proc fftw_plan_dft_1d*(n: cint; `in`: ptr Complex64; `out`: ptr Complex64; sign: cint; flags: cuint): fftw_plan {.cdecl, importc: "fftw_plan_dft_1d", dynlib: LibraryName.}


proc fftw_export_wisdom_to_filename*(filename: cstring): cint {.cdecl,
    importc: "fftw_export_wisdom_to_filename", dynlib: LibraryName.}

proc fftw_import_wisdom_from_filename*(filename: cstring): cint {.cdecl,
    importc: "fftw_import_wisdom_from_filename", dynlib: LibraryName.}

proc fftw_destroy_plan*(p: fftw_plan) {.cdecl, importc: "fftw_destroy_plan",
                                        dynlib: LibraryName.}

