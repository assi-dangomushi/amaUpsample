# amaUpsample

upsampling soft(44.1KHz to 96KHz)

read from stdin(int32, 2ch) and write to stdout(int32, 2ch)

## environment
Linux Ubuntu22.04 or RaspberryPi OS bookworm

## install

install gcc, libfftw3-dev, sox
~~~
sudo apt install gcc libfftw3-dev sox
~~~

install nim

see https://nim-lang.org/

## compile

~~~
nim c -d:release amaUpsample.nim
~~~

## Usage

~~~
amaUpsample coefFile Samplerate[4800|96000|192000|384000] gain(dB)
~~~

sample coefFile

+ coef1_linear: linear phase
+ coef1_minimum: minimum phase

convert test_44k.wav(16bit or 24bit or 32bit) to test_96k.wav(32bit) gain:-1.5dB

~~~
sox test44k.wav -t raw -e s -b 32 - | ./amaUpsample coef1_linear 96000 -1.5 | sox -t raw -c 2 -e s -b 32 -r 96000 - test_96k.wav
~~~

