#!/usr/bin/env powershell -File
# [rights]  Copyright 2020 brianddk at github https://github.com/brianddk
# [license] Apache 2.0 License https://www.apache.org/licenses/LICENSE-2.0
# [repo]    github.com/brianddk/reddit/blob/master/python/dump-blkdat.py
# [btc]     BTC-b32: bc1qwc2203uym96u0nmq04pcgqfs9ldqz9l3mz8fpj
# [tipjar]  github.com/brianddk/reddit/blob/master/tipjar/tipjar.txt
# [ref]     https://www.reddit.com/r/Bitcoin/comments/ju03w9/
# [note]    Expand-Archive and Get-FileHash are not available in Win8 / Win2012

$mingw       = "C:\MinGW"
$msys        = "C:\msys\1.0"
$src         = "src"
$archive     = "var\opt\archive"
$bitcoin     = "bitcoin-0.1.0"
$tmp         = "tmp"
$perl        = "C:\Perl58"
$z7          = "C:\Program Files (x86)\7-Zip\7z.exe"

$sourceforge = "https://downloads.sourceforge.net"
$github      = "https://github.com"
$oracle      = "https://download.oracle.com"
$berryperl   = "http://strawberryperl.com"
$amazonaws   = "https://s3.amazonaws.com"
$filelist    = @"
0b431b557399c1b3948c13c803a22c95;;                                                ;$sourceforge/gnuwin32/zlib-1.2.3-bin.zip
a1155c41b1954a2f6da1014c7c1a1263;;                                                ;$sourceforge/gnuwin32/bzip2-1.0.5-bin.zip
f2bd5a4ee39d9fc64b456d516f90afad;;                                                ;$sourceforge/gnuwin32/libarchive-2.4.12-1-bin.zip
6bba3bd1bf510d152a42d0beeeefa14d;;                                                ;$sourceforge/mingw/binutils-2.19.1-mingw32-bin.tar.gz
3be0d55e058699b615fa1d7389a8ce41;;                                                ;$sourceforge/mingw/gcc-core-3.4.5-20051220-1.tar.gz
99059fbaa93fa1a29f5571967901e11f;;                                                ;$sourceforge/mingw/gcc-g++-3.4.5-20051220-1.tar.gz
f24d63744af66b54547223bd5476b8f0;;                                                ;$sourceforge/mingw/mingwrt-3.15.2-mingw32-dev.tar.gz
688866a2de8d17adb50c54a2a1edbab4;;                                                ;$sourceforge/mingw/mingwrt-3.15.2-mingw32-dll.tar.gz
a50fff6bc1e1542451722e2650cb53b4;;                                                ;$sourceforge/mingw/w32api-3.13-mingw32-dev.tar.gz
8692c3c6967f7530a2ad562fe69781d2;;                                                ;$sourceforge/mingw/mingw32-make-3.81-20080326-2.tar.gz
cf95067cc749b00bf5b81deb40a8e16c;;                                                ;$sourceforge/mingw/MSYS-1.0.11.exe
f7aeebb16dc3b0f19b018506ed743fbb;;                                                ;$sourceforge/mingw/msysDTK-1.0.1.exe
6d13be3328233a06d9db89a961690f14;;                                                ;$sourceforge/sevenzip/7z465.msi
79b4148f26fb3a7e7c30c8956b193880;;                                                ;$berryperl/download/5.8.8/strawberry-perl-5.8.8.2.zip
4959877a1dde3125cc627b1ed16b5916;$tmp\bitcoin\src        ;$src\$bitcoin           ;$amazonaws/nakamotoinstitute/code/bitcoin-0.1.0.rar
faabfaa824915401e709d26a1432b7f7;wxWidgets-2.8.9         ;$src\$bitcoin\wxWidgets ;$sourceforge/wxwindows/wxWidgets-2.8.9.zip
368d680fe87f395f9d161a45d6248f4d;openssl-OpenSSL_0_9_8h  ;$src\$bitcoin\OpenSSL   ;$github/openssl/openssl/archive/OpenSSL_0_9_8h.zip
0582ef9de0cbc9d3ad89598ded6b56b5;db-4.7.25.NC            ;$src\$bitcoin\DB        ;$oracle/berkeley-db/db-4.7.25.NC.zip
759a753cb4cdb1ec68c211d3b9d971b0;boost_1_34_1            ;$src\$bitcoin\boost     ;$sourceforge/boost/boost_1_34_1.zip
72615486b39b0b6f5dfa91df531b7f7e;boost-jam-3.1.17-1-ntx86;$src\$bitcoin\boost\bjam;$sourceforge/boost/boost-jam/boost-jam-3.1.17-1-ntx86.zip
"@

New-Item -Path "$msys\$src" -ItemType Directory -Force | Out-Null
New-Item -Path "$msys\$archive" -ItemType Directory -Force | Out-Null
New-Item -Path "$mingw" -ItemType Directory -Force | Out-Null
New-Item -Path "$perl" -ItemType Directory -Force | Out-Null

Push-Location $mingw
$secpro = [Net.ServicePointManager]::SecurityProtocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]($secpro -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12)
[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
foreach ($item in $filelist.Split("`n"))
{
    $hash, $from, $to, $uri = $item.Trim().Split(";")
    $file = $uri.Split('/')[-1]
    if ((Test-Path $file) -or (Test-Path "$msys\$archive\$file")) {}
    else {
        Write-Output "$hash, $uri"
        Invoke-WebRequest -UserAgent "curl/7.55.1" -Uri "$uri" -OutFile "$file"
        if (!$?) { throw "Download Failed [$file]" }
        $gfh = (CertUtil.exe -HashFile "$file" MD5).Split("`n")[1].Trim().replace(" ", "")
        if ($gfh -ne $hash) { throw "Hash Failed [$file]" }
    }
}

$zips = Get-ChildItem *.zip | Sort-Object -Property CreationTimeUtc
foreach ($file in $zips)
{
    if ($file.Name.ToLower().StartsWith("strawberry-perl"))
    {
        Set-Location $perl
    }
    if (Test-Path ".\bin\bsdtar.exe")
    {
        Write-Output "UnTaring $file"
        bin\bsdtar.exe -xf "$file"
        if (!$?) { throw "Untar Failed [$file]" }
    }
    else
    {
        Write-Output "Extracting $file"
        [System.IO.Compression.ZipFile]::ExtractToDirectory($file.FullName, $tmp)
        if (!$?) { throw "Unzip Failed [$file]" }
        robocopy.exe /s /mov /nfl /ndl /njh /njs "$tmp" "$PWD" | Out-Null
        Get-ChildItem $tmp | Remove-Item -Recurse -Force
    }
    Move-Item $file.FullName "$msys\$archive"
    Set-Location $mingw
}

foreach ($file in Get-ChildItem @("*.tar.gz", "*.msi"))
{
    if ($file.Extension -eq ".msi")
    {
        Write-Output "MSI installing $file"
        msiexec /package $file.FullName /quiet | Out-Null
        if (!$?) { throw "MSI Install Failed [$file]" }
    }
    else
    {
        Write-Output "UnTaring $file"
        bin\bsdtar.exe -xzf $file.Name
        if (!$?) { throw "Untar Failed [$file]" }
    }
    Move-Item $file.Name "$msys\$archive"
}

Get-ChildItem "msys*.exe" | Move-Item -Destination "$msys\$archive"

foreach ($item in $filelist.Split("`n"))
{
    $hash, $from, $to, $uri = $item.Trim().Split(";")
    $file = $uri.Split('/')[-1]
    $from = $from.Trim()
    $to   = $to.Trim()
    if ($file.StartsWith("bitcoin-") -and $file.EndsWith("rar") -and (Test-Path $file))
    {
        Write-Output "UnArcing $file"
        &$z7 "x" "-aoa" "-o$tmp\bitcoin" "$file" | Out-Null
        Move-Item $file "$msys\$archive"
    }
    if ($from.Length + $to.Length -gt 0)
    {
        if (Test-Path $from) 
        {
            Write-Output "Moving $mingw\$from to $msys\$to"
            Move-Item "$mingw\$from" "$msys\$to" 
        }
    }
}

if (Test-Path "$perl\perl") 
{
    Write-Output "Installing Perl"
    Set-Location "$perl"
    Get-ChildItem "perl" | Move-Item -Destination $PWD
}

$retired = @"
102e4767c393db578c440f67882f813f;;;$sourceforge/mingw/msysCORE-1.0.11-bin.tar.gz
e3ae6e5fc6b4ddb4b784b88e44be467c;;;$sourceforge/mingw/msysCORE-1.0.11-msys-1.0.11-base-bin.tar.lzma
b24802293f74ab11aaa5786f36c59819;;;$sourceforge/gnuwin32/gzip-1.3.12-1-bin.zip
"@

$openssl_patch = @"
diff -ura --strip-trailing-cr OpenSSL/crypto/err/err_all.c OpenSSL-0.9.8h/crypto/err/err_all.c
--- OpenSSL/crypto/err/err_all.c	2008-05-28 01:37:14 -0700
+++ OpenSSL-0.9.8h/crypto/err/err_all.c	2020-11-14 14:37:21 -0800
@@ -98,6 +98,7 @@
 #include <openssl/cms.h>
 #endif
 
+void ERR_load_RSA_strings(void) { }
 void ERR_load_crypto_strings(void)
 	{
 #ifndef OPENSSL_NO_ERR
diff -ura --strip-trailing-cr OpenSSL/engines/e_gmp.c OpenSSL-0.9.8h/engines/e_gmp.c
--- OpenSSL/engines/e_gmp.c	2008-05-28 01:37:14 -0700
+++ OpenSSL-0.9.8h/engines/e_gmp.c	2020-11-14 14:35:24 -0800
@@ -85,7 +85,9 @@
 #include <openssl/crypto.h>
 #include <openssl/buffer.h>
 #include <openssl/engine.h>
+#ifndef OPENSSL_NO_RSA
 #include <openssl/rsa.h>
+#endif
 #include <openssl/bn.h>
 
 #ifndef OPENSSL_NO_HW
diff -ura --strip-trailing-cr OpenSSL/ms/mingw32.bat OpenSSL-0.9.8h/ms/mingw32.bat
--- OpenSSL/ms/mingw32.bat	2008-05-28 01:37:14 -0700
+++ OpenSSL-0.9.8h/ms/mingw32.bat	2020-11-14 17:15:44 -0800
@@ -1,7 +1,7 @@
 @rem OpenSSL with Mingw32+GNU as
 @rem ---------------------------
 
-perl Configure mingw %1 %2 %3 %4 %5 %6 %7 %8
+perl Configure mingw threads no-rc2 no-rc4 no-rc5 no-idea no-des no-bf no-cast no-aes no-camellia no-seed no-rsa no-dh
 
 @echo off
 
@@ -80,7 +80,7 @@
 
 echo Building the libraries
 mingw32-make -f ms/mingw32a.mak
-if errorlevel 1 goto end
+REM  if errorlevel 1 goto end
 
 echo Generating the DLLs and input libraries
 dllwrap --dllname libeay32.dll --output-lib out/libeay32.a --def ms/libeay32.def out/libcrypto.a -lwsock32 -lgdi32
"@
Set-Content -Path "$msys\$src\$bitcoin\OpenSSL\OpenSSL.patch" -Value $openssl_patch

$buildall = @"
setlocal
set oldpath=%path%
set mingw=$mingw\mingw32\bin;$mingw\bin;$perl\bin;%path%
set msys=$mingw\mingw32\bin;$mingw\bin;$msys\bin;%path%
set home=$msys\$src\$bitcoin

REM OpenSSL
set PATH=%mingw%
cd /d %home%\OpenSSL
if exist OpenSSL.patch $msys\bin\patch.exe -p0 -Nl -r /tmp/OpenSSL -i "%cd%\OpenSSL.patch" -d ..
call ms\mingw32.bat 2>&1 | $msys\bin\tee.exe '%home%\OpenSSL.log'

REM Berkeley DB
set PATH=%msys%
cd /d %home%\DB\build_unix
sh.exe --login -c "cd '%cd%';../dist/configure --enable-mingw --enable-cxx" 2>&1 | $msys\bin\tee.exe '%home%\DB.log'
make.exe 2>&1 | $msys\bin\tee.exe -a '%home%\DB.log'

REM Boost
set PATH=%mingw%
cd /d %home%\Boost
bjam\bjam.exe toolset=gcc --build-type=complete stage 2>&1 | $msys\bin\tee.exe '%home%\Boost.log'

REM wxWidgets
set PATH=%mingw%
cd /d %home%\wxWidgets\build\msw
mingw32-make.exe -f makefile.gcc 2>&1 | $msys\bin\tee.exe '%home%\wxWidgets.log'

REM bitcoin
if exist s:\ subst s: /d
subst s: %home%
set PATH=%mingw%
cd /d s:\
robocopy.exe /s /ndl /njh /njs \OpenSSL\outinc \OpenSSL\include
robocopy.exe /s /ndl /njh /njs \wxWidgets\lib\gcc_lib\mswd \wxWidgets\lib\vc_lib\mswd
if not exist \obj mkdir \obj
mingw32-make.exe bitcoin.exe -f makefile 2>&1 | $msys\bin\tee.exe '%home%\bitcoin.log'
subst s: /d

REM Prepare Distribution
cd /d %home%
if not exist dist mkdir dist
strip "bitcoin.exe" -o "dist\bitcoin.exe"
strip "OpenSSL\libeay32.dll" -o "dist\libeay32.dll"
strip "$mingw\bin\mingwm10.dll" -o "dist\mingwm10.dll"

popd
set PATH=%oldpath%
endlocal
"@
Set-Content -Path "$msys\$src\$bitcoin\buildAll.cmd" -Value $buildall

Pop-Location
Write-Output "All Done`nInstalled $mingw and $perl"
Write-Output "Now run msys*.exe then msysDTK*.exe from $msys\$archive"
Write-Output "Then run $msys\$src\$bitcoin\buildAll.cmd to build everything"
Write-Output "If it works it will be placed in $msys\$src\$bitcoin\dist"
Write-Output "Obviously, you can't run it on an open network, so don't!"
