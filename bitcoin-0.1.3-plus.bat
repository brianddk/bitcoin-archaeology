@if (@X == @Y) @end /*
:: [rights]  Copyright 2020 brianddk at github https://github.com/brianddk
:: [license] Apache 2.0 License https://www.apache.org/licenses/LICENSE-2.0
:: [repo]    github.com/brianddk/bitcoin-archaeology/blob/main/bitcoin-0.1.3.bat
:: [btc]     BTC-b32: bc1qwc2203uym96u0nmq04pcgqfs9ldqz9l3mz8fpj
:: [tipjar]  github.com/brianddk/reddit/blob/master/tipjar/tipjar.txt
::
:: Don't panic, yes, this is a hybrid batch file that runs as both batch and
::    "JavaScript", or at least Microsoft's version of it.  References are
::    included, but the original docs sites have long since vanished.
::
:: This file will unpack and install all the archives required to bootstrap
::    your build environment.  You will need to get the files to the build
::    machine yourself, since 2008 OSes don't usually have the required CA
::    root certificates or TLS1.2 enabled.  The easiest way to do this is to
::    just open an RDP session and copy from //tsclient/c
::
:: References:
:: @if/@end: https://web.archive.org/web/20100904060320/http://msdn.microsoft.com/en-us/library/58dz2w55(VS.85).aspx
:: JScript:  https://web.archive.org/web/20101204120821/http://msdn.microsoft.com/en-us/library/yek4tbz0(VS.85).aspx
:: WSH:      https://web.archive.org/web/20081227104418/http://msdn2.microsoft.com/en-us/library/9bbdkx3k.aspx
:: Heredoc:  https://stackoverflow.com/a/14496573
:: Hybrid:   https://gist.github.com/DavidRuhmann/5199433

:: Batch Section
@echo off
setlocal
goto:main

:main
   CScript //E:JScript //Nologo "%~f0"
exit /b

:end
endlocal
exit /b

*/// JScript Section

var mingw = "c:\\MinGW";
var msys = "c:\\msys\\1.0";
var archive = msys +"\\opt\\var\\archive";
var perl  = "c:\\Perl58";
var bitcoin = "bitcoin-0.1.3-plus"
var tags = ["$mingw", "$msys", "$archive", "$perl", "$bitcoin"]

function main(){
   mkDirs([mingw]);
   chDir(mingw);
   json = parseTags(dependencies_json, tags, true);
   var depends = eval(json);
   for (var i in depends) {
      var node = depends[i];
      print(node.name);
      fn = eval(node.installer);
      if (!fn(node)) {
         print("  Failed on "+node.name);
         exit(1);
      }
   }
   print("");
   placeFile(buildAll_bat, msys+"\\src\\"+bitcoin+"\\buildAll.bat")
   placeFile(dependencies_json, msys+"\\src\\"+bitcoin+"\\dependencies.json")
   placeFile(openssl_patch_gz_b64, msys+"\\src\\"+bitcoin+"\\OpenSSL\\OpenSSL.patch.gz.b64")
   placeFile(bitcoin_patch_gz_b64, msys+"\\src\\"+bitcoin+"\\"+bitcoin+".patch.gz.b64")

   print("\nSuccess!!");

   print("");
   print(parseTags(closing_msg, tags));
}

function nullInfoOnly(node) {
   return true;
}

function msiInstall(node){
   var file = getFile(node);
   var sevenzip = "C:\\Program Files (x86)\\7-Zip";
   var oEnv = wso.Environment("PROCESS");
   var sPath = oEnv("PATH") +";"+ sevenzip;
   oEnv("PATH") = sPath;
   if (fso.FileExists(sevenzip+"\\7z.exe") || isDone(file)) {
      return moveToArch(file);
   }
   else {
      if(hashCheck(node)) {
         var msi = wso.CurrentDirectory +"\\"+ file;
         var cmd = "msiexec /package "+msi+" /quiet";
         var gco = getCmdOut(cmd);
         print("  Install of: "+file+" complete rc:"+gco.oExec.ExitCode);
         if(gco.oExec.ExitCode == 0) {return moveToArch(file);}
      }
   }
   return false;
}

function mingwUnzip(node) {
   var file = getFile(node);
   var mingw = node.moveTo;
   print(file+" "+mingw);
   if(isDone(file)){
      return moveToArch(file);;
   }
   else {
      if(hashCheck(node)) {
         mkDirs([mingw]);
         if(unzip(mingw+"\\"+file, mingw)){
            if(file.slice(-6) == "tar.gz"){
               var tar = file.slice(0, -3)
               if(unzip(mingw+"\\"+tar, mingw)){
                  fso.DeleteFile(tar);
               }
               else {
                  return false;
               }
            }
            return moveToArch(file);
         }
      }
   }
   return false;
}

function msysStaging(node) {
   var file = getFile(node);
   if(isDone(file) || hashCheck(node)) {
      return moveToArch(file);
   }
   return false;
}

function perlInstaller(node) {
   var file = getFile(node);
   var perl = node.moveTo
   if(isDone(file)) {
      return moveToArch(file);
   }
   if(hashCheck(node)) {
      mkDirs([perl]);
      if(unzip(mingw+"\\"+file, perl)){
         perl += "\\"
         var dirs = ["bin", "lib", "site"]
         for (i in dirs) {
            var dir = dirs[i];
            if(fso.FolderExists(perl+dir)) {
               fso.DeleteFolder(perl+dir, true);
            }
            fso.MoveFolder(perl+"perl\\"+dir, perl);
         }
         fso.DeleteFolder(perl+"perl");
         return moveToArch(file);
      }
   }
   return false;
}

function tmpSrcMover(node) {
   var file = getFile(node);
   if(isDone(file)) {
      return moveToArch(file);
   }
   if(hashCheck(node)) {
      var tmp = mingw+"\\tmp"
      mkDirs([tmp, msys+"\\src"])
      if(unzip(mingw+"\\"+file, tmp)){
         var src = mingw +"\\"+ node.moveFrom
         var dst = msys +"\\"+ node.moveTo
         fso.MoveFolder(src, dst);
         return moveToArch(file);
      }
   }
   return false;
}

function unzip(file, dest) {
   cmd = "7z.exe x -r -bd -y -aoa -o"+dest+" "+file;
   gco = getCmdOut(cmd);
   if(gco.oExec.ExitCode){
      print(gco.error)
      return false;
   }
   return true;
}

function moveToArch(file) {
   var dest = archive+"\\"+file;
   var parent = msys.split("\\").slice(0,-1).join("\\");
   mkDirs([parent,
           msys,
           msys+"\\opt",
           msys+"\\opt\\var",
           archive]);

   if(fso.FileExists(dest)) {
      if(fso.FileExists(file)) {fso.DeleteFile(file);}
   }
   else {
      fso.MoveFile(file, dest);
   }
   return true;
}

function mkDirs(dirs) {
   for(i in dirs) {
      dir = dirs[i];
      if(!fso.FolderExists(dir)){
         fso.CreateFolder(dir);
      }
   }
}

function hashCheck(node) {
   var file = getFile(node);
   if(fso.FileExists(file)) {
      output = getCmdOut("certutil -hashfile "+file).output;
      var hash = output.split("\n")[1].replace(/\r/g,"").replace(/ /g, "");
   }
   return (hash == node.shaHash)
}

function getCmdOut(cmd) {
   var output = "";
   var error = "";
   print('  Executing: "'+cmd+'"')
   var oExec = wso.Exec(cmd);
   while(true){
      output += oExec.StdOut.ReadAll();
      if (oExec.StdOut.AtEndOfStream) {
         if(oExec.Status != RUNNING) {break;}
      }
   }
   while(!oExec.StdErr.AtEndOfStream){
      error += oExec.StdErr.ReadAll();
   }
   return {
      oExec: oExec,
      output: output,
      error: error
   }
}

function getCmdNul(cmd) {
   var oExec = wso.Exec(cmd);
   while(true){
      sleep(100)
      if(oExec.Status != RUNNING) {break;}
   }
   return {
      oExec: oExec
   }
}

function placeFile(content, filename) {
   content = parseTags(content, tags);
   print("  Placing "+filename);
   fh = fso.CreateTextFile(filename, true, false);
   fh.Write(content);
   fh.Close();
}

function parseTags(data, tags, isJson) {
   for (var i in tags) {
      var tag = tags[i];
      var global = tag.slice(1);
      global = eval(global)
      if(isJson) {
         global = global.replace(/\\/g, "\\\\");
      }
      data = data.replace(new RegExp("\\"+tag, "mg"), global);
   }
   return data;
}

function heredoc(fn) {
   return fn.toString().match(/{\/\*$\s*([\s\S]*?)\s*^\*\/}$/m)[1];
};

var dependencies_json = heredoc(function () {/*
[
   {
      "name": "VirtualBox Hypervisor v6.1.12",
      "url": "https://download.virtualbox.org/virtualbox/6.1.12/VirtualBox-6.1.12-139181-Win.exe",
      "altUrl": "http://web.archive.org/web/20200817133322/https://download.virtualbox.org/virtualbox/6.1.12/VirtualBox-6.1.12-139181-Win.exe",
      "installer": "nullInfoOnly",
      "archive": "https://web.archive.org/web/20201114012321/https://www.virtualbox.org/wiki/Download_Old_Builds_6_1",
      "md5Hash": "3eed9c1a02df46408c59444e5ee00b24",
      "shaHash": "790e63ba196fac1dce4f24f3be7ca893a111fd69"
   },
   {
      "name": "Windows 2008 (Hyper-V) ISO",
      "url": "file://ServerHyper_MUIx2-080912.iso",
      "altUrl": "http://web.archive.org/web/20201012144846/https://download.microsoft.com/download/D/D/B/DDB17DC1-A879-44DD-BD11-C0991D292AD7/6001.18000.080118-1840_x86fre_Server_en-us-KRMSFRE_EN_DVD.iso",
      "installer": "nullInfoOnly",
      "archive": "https://web.archive.org/web/20090518021514/http://www.microsoft.com/downloads/details.aspx?FamilyId=6067CB24-06CC-483A-AF92-B919F699C3A0&displaylang=en",
      "altArchive": "https://www.microsoft.com/en-us/download/details.aspx?id=5023",
      "md5Hash": "8ceb7bc0ae36dc5344a01a811d163bfd",
      "shaHash": "10731c3027a0352ab4ff5f7a575b028765310c38"
   },
   {
      "name": "7-Zip Archive Utility v4.57",
      "url": "https://downloads.sourceforge.net/sevenzip/7z457.msi",
      "altUrl": "http://web.archive.org/web/20200505151811/https://liquidtelecom.dl.sourceforge.net/project/sevenzip/7-Zip/4.57/7z457.msi",
      "installer": "msiInstall",
      "archive": "https://web.archive.org/web/20201103004120/https://sourceforge.net/projects/sevenzip/files/7-Zip/4.57/",
      "md5Hash": "3f4a68083169bf7d10e542a3e89f5895",
      "shaHash": "998f1cbd9ac267e9df9485b122ae1f6ab1b52446"
   },
   {
      "name": "MinGW binutils v2.19.1",
      "url": "https://downloads.sourceforge.net/mingw/binutils-2.19.1-mingw32-bin.tar.gz",
      "altUrl": "http://web.archive.org/web/20201110024217/https://master.dl.sourceforge.net/project/mingw/OldFiles/binutils-2.19.1/binutils-2.19.1-mingw32-bin.tar.gz",
      "moveTo": "$mingw",
      "installer": "mingwUnzip",
      "archive": "https://web.archive.org/web/20201117141621/https://sourceforge.net/projects/mingw/files/OldFiles/binutils-2.19.1/",
      "md5Hash": "6bba3bd1bf510d152a42d0beeeefa14d",
      "shaHash": "1ab72f3af3fe96d08c3c9bff60c47913704d5774"
   },
   {
      "name": "MinGW gcc compiler core v3.4.5",
      "url": "https://downloads.sourceforge.net/mingw/gcc-core-3.4.5-20051220-1.tar.gz",
      "altUrl": "http://web.archive.org/web/20201119002318/https://master.dl.sourceforge.net/project/mingw/OldFiles/gcc-core-3.4.5-20051220-1.tar.gz",
      "moveTo": "$mingw",
      "installer": "mingwUnzip",
      "archive": "https://web.archive.org/web/20200510133019/https://sourceforge.net/projects/mingw/files/OldFiles/",
      "md5Hash": "3be0d55e058699b615fa1d7389a8ce41",
      "shaHash": "f9044194ce21340e15c71063173c34fa2d79f8c7"
   },
   {
      "name": "MinGW gcc C++ compiler v3.4.5",
      "url": "https://downloads.sourceforge.net/mingw/gcc-g++-3.4.5-20051220-1.tar.gz",
      "altUrl": "http://web.archive.org/web/20201119075938/https://master.dl.sourceforge.net/project/mingw/OldFiles/gcc-g++-3.4.5-20051220-1.tar.gz",
      "moveTo": "$mingw",
      "installer": "mingwUnzip",
      "archive": "https://web.archive.org/web/20200510133019/https://sourceforge.net/projects/mingw/files/OldFiles/",
      "md5Hash": "99059fbaa93fa1a29f5571967901e11f",
      "shaHash": "7cd083f99f5b3c0d8e4cd83876f09914bcdb5325"
   },
   {
      "name": "MinGW Windows Runtime development v3.15.2",
      "url": "https://downloads.sourceforge.net/mingw/mingwrt-3.15.2-mingw32-dev.tar.gz",
      "altUrl": "http://web.archive.org/web/20191025083449/https://master.dl.sourceforge.net/project/mingw/OldFiles/mingwrt-3.15.2/mingwrt-3.15.2-mingw32-dev.tar.gz",
      "moveTo": "$mingw",
      "installer": "mingwUnzip",
      "archive": "https://web.archive.org/web/20201117142936/https://sourceforge.net/projects/mingw/files/OldFiles/mingwrt-3.15.2/",
      "md5Hash": "f24d63744af66b54547223bd5476b8f0",
      "shaHash": "9f562408b94202ecff558e683e5d7df5440612c4"
   },
   {
      "name": "MinGW Windows Runtime shared library v3.15.2",
      "url": "https://downloads.sourceforge.net/mingw/mingwrt-3.15.2-mingw32-dll.tar.gz",
      "altUrl": "http://web.archive.org/web/20201119074837/https://master.dl.sourceforge.net/project/mingw/OldFiles/mingwrt-3.15.2/mingwrt-3.15.2-mingw32-dll.tar.gz",
      "moveTo": "$mingw",
      "installer": "mingwUnzip",
      "archive": "https://web.archive.org/web/20201117142936/https://sourceforge.net/projects/mingw/files/OldFiles/mingwrt-3.15.2/",
      "md5Hash": "688866a2de8d17adb50c54a2a1edbab4",
      "shaHash": "18fad088b4fb8dafa59b114dbd4caaeeb81d22f4"
   },
   {
      "name": "MinGW Win32 development v3.13",
      "url": "https://downloads.sourceforge.net/mingw/w32api-3.13-mingw32-dev.tar.gz",
      "altUrl": "http://web.archive.org/web/20170327022629/https://master.dl.sourceforge.net/project/mingw/OldFiles/w32api-3.13/w32api-3.13-mingw32-dev.tar.gz",
      "moveTo": "$mingw",
      "installer": "mingwUnzip",
      "archive": "https://web.archive.org/web/20200510133019/https://sourceforge.net/projects/mingw/files/OldFiles/w32api-3.13/",
      "md5Hash": "a50fff6bc1e1542451722e2650cb53b4",
      "shaHash": "5eb7d8ec0fe032a92bea3a2c8282a78df2f1793c"
   },
   {
      "name": "MinGW make utility v3.81",
      "url": "https://downloads.sourceforge.net/mingw/mingw32-make-3.81-20080326-2.tar.gz",
      "altUrl": "http://web.archive.org/web/20190924230629/https://master.dl.sourceforge.net/project/mingw/OldFiles/mingw-make/mingw32-make-3.81-20080326-2.tar.gz",
      "moveTo": "$mingw",
      "installer": "mingwUnzip",
      "archive": "https://sourceforge.net/projects/mingw/files/OldFiles/mingw-make/",
      "md5Hash": "8692c3c6967f7530a2ad562fe69781d2",
      "shaHash": "361ebee1c9865bc509f63b008351351cb0d6df8e"
   },
   {
      "name": "MSYS Installer v1.0.11",
      "url": "https://downloads.sourceforge.net/mingw/MSYS-1.0.11.exe",
      "altUrl": "http://web.archive.org/web/20201119080626/https://versaweb.dl.sourceforge.net/project/mingw/MSYS/Base/msys-core/msys-1.0.11/MSYS-1.0.11.exe",
      "installer": "msysStaging",
      "archive": "https://web.archive.org/web/20160604080745/https://sourceforge.net/projects/mingw/files/MSYS/Base/msys-core/msys-1.0.11/",
      "md5Hash": "cf95067cc749b00bf5b81deb40a8e16c",
      "shaHash": "1edad9d1b67b48c92781b3ccddbd1cc9ce64d78a"
   },
   {
      "name": "MSYS Dev Toolkit Installer v1.0.11",
      "url": "https://downloads.sourceforge.net/mingw/msysDTK-1.0.1.exe",
      "altUrl": "http://web.archive.org/web/20191022110605/https://versaweb.dl.sourceforge.net/project/mingw/Other/Unsupported/MSYS/msysDTK/msysDTK-1.0.1/msysDTK-1.0.1.exe",
      "installer": "msysStaging",
      "archive": "https://web.archive.org/web/20150223183455/http://sourceforge.net/projects/mingw/files/Other/Unsupported/MSYS/msysDTK/msysDTK-1.0.1/",
      "md5Hash": "f7aeebb16dc3b0f19b018506ed743fbb",
      "shaHash": "7d23aa6eb28fbaf338bb3586fa7179448f2c7327"
   },
   {
      "name": "Strawberry Perl for Windows v5.8.8.2",
      "url": "http://strawberryperl.com/download/5.8.8/strawberry-perl-5.8.8.2.zip",
      "altUrl": "http://web.archive.org/web/20190620073115/http://strawberryperl.com/download/5.8.8/strawberry-perl-5.8.8.2.zip",
      "moveTo": "$perl",
      "installer": "perlInstaller",
      "archive": "https://web.archive.org/web/20081218021515/http://strawberryperl.com/",
      "md5Hash": "79b4148f26fb3a7e7c30c8956b193880",
      "shaHash": "a5a5271c7220966078aceb4199ad7efd83d69fc5"
   },
   {
      "name": "Bitcoin Core Source v0.1.3",
      "url": "https://s3.amazonaws.com/nakamotoinstitute/code/bitcoin-0.1.3.rar",
      "altUrl": "http://web.archive.org/web/20171223053826/https://s3.amazonaws.com/nakamotoinstitute/code/bitcoin-0.1.3.rar",
      "moveFrom": "tmp\\src",
      "moveTo": "src\\$bitcoin",
      "installer": "tmpSrcMover",
      "archive": "https://web.archive.org/web/20201108130208/https://satoshi.nakamotoinstitute.org/code/",
      "md5Hash": "9a73e0826d5c069091600ca295c6d224",
      "shaHash": "294c684fbaa13ae2662e612e98d288bde0ba2b88"
   },
   {
      "name": "wxWidgets Toolkit Source v2.8.9",
      "url": "https://downloads.sourceforge.net/wxwindows/wxWidgets-2.8.9.zip",
      "altUrl": "http://web.archive.org/web/20201119081141/https://master.dl.sourceforge.net/project/wxwindows/2.8.9/wxWidgets-2.8.9.zip",
      "moveFrom": "tmp\\wxWidgets-2.8.9",
      "moveTo": "src\\$bitcoin\\wxWidgets",
      "installer": "tmpSrcMover",
      "archive": "https://web.archive.org/web/20180617195338/https://sourceforge.net/projects/wxwindows/files/2.8.9/",
      "md5Hash": "faabfaa824915401e709d26a1432b7f7",
      "shaHash": "2f9b4d63e467375c0c699981522de43f3476abb6"
   },
   {
      "name": "OpenSSL Source v0.9.8h",
      "url": "https://github.com/openssl/openssl/archive/OpenSSL_0_9_8h.zip",
      "altUrl": "http://web.archive.org/web/20201118042952/https://codeload.github.com/openssl/openssl/zip/OpenSSL_0_9_8h",
      "moveFrom": "tmp\\openssl-OpenSSL_0_9_8h",
      "moveTo": "src\\$bitcoin\\OpenSSL",
      "installer": "tmpSrcMover",
      "archive": "https://web.archive.org/web/20201118042952/https://codeload.github.com/openssl/openssl/zip/OpenSSL_0_9_8h",
      "md5Hash": "368d680fe87f395f9d161a45d6248f4d",
      "shaHash": "bdbfd85b664f28254390349cae0050eaf65a9ae0"
   },
   {
      "name": "Berkely DB Source v4.7.25",
      "url": "https://download.oracle.com/berkeley-db/db-4.7.25.NC.zip",
      "altUrl": "http://web.archive.org/web/20151018184152/http://download.oracle.com/berkeley-db/db-4.7.25.NC.zip",
      "moveFrom": "tmp\\db-4.7.25.NC",
      "moveTo": "src\\$bitcoin\\DB",
      "installer": "tmpSrcMover",
      "archive": "https://web.archive.org/web/20090125154740/http://en.wikipedia.org/wiki/Berkeley_DB",
      "md5Hash": "0582ef9de0cbc9d3ad89598ded6b56b5",
      "shaHash": "d3bba11b3a1f86f3ea5a82dda73ca0dd2526d8e0"
   },
   {
      "name": "Boost Toolkit Source v1.34.1",
      "url": "https://downloads.sourceforge.net/boost/boost_1_34_1.zip",
      "altUrl": "http://web.archive.org/web/20201118044413/https://master.dl.sourceforge.net/project/boost/boost/1.34.1/boost_1_34_1.zip",
      "moveFrom": "tmp\\boost_1_34_1",
      "moveTo": "src\\$bitcoin\\boost",
      "installer": "tmpSrcMover",
      "archive": "https://web.archive.org/web/20161201185548/https://sourceforge.net/projects/boost/files/boost/1.34.1/",
      "md5Hash": "759a753cb4cdb1ec68c211d3b9d971b0",
      "shaHash": "90a10d2e3591fcaa2b8cd10121980133af3eb2ff"
   },
   {
      "name": "Boost Jam Build Utility v3.1.17",
      "url": "https://downloads.sourceforge.net/boost/boost-jam/boost-jam-3.1.17-1-ntx86.zip",
      "altUrl": "http://web.archive.org/web/20201118044132/https://master.dl.sourceforge.net/project/boost/boost-jam/3.1.17/boost-jam-3.1.17-1-ntx86.zip",
      "moveFrom": "tmp\\boost-jam-3.1.17-1-ntx86",
      "moveTo": "src\\$bitcoin\\boost\\bjam",
      "installer": "tmpSrcMover",
      "archive": "https://web.archive.org/web/20201118043751/https://sourceforge.net/projects/boost/files/boost-jam/3.1.17/",
      "md5Hash": "72615486b39b0b6f5dfa91df531b7f7e",
      "shaHash": "2707afe3101fffe77f2a8d189b75652e0408cc99"
   }
]
*/});

var buildAll_bat = heredoc(function () {/*
setlocal
set oldpath=%path%
set mingw=$mingw\mingw32\bin;$mingw\bin;$perl\bin;%path%
set msys=$mingw\mingw32\bin;$mingw\bin;$msys\bin;%path%
set home=$msys\src\$bitcoin
set tee=$msys\bin\tee.exe

REM Verify patch / diff
REM The diff and patch utilities "change" over time, and are very picky
set PATH=%msys%
diff.exe -v | findstr /r "^diff (GNU diffutils) 2\.8\.7$" || goto :error
patch.exe --version | findstr /r "^patch 2\.5\.4$" || goto :error

REM OpenSSL
cd /d %home%\OpenSSL
set patchfile=OpenSSL.patch
set PATH=%msys%
if not exist done. (
   if not exist %patchfile% (
      openssl.exe enc -d -a < %patchfile%.gz.b64 | gzip.exe -dc > %patchfile%
      patch.exe -p1 -Nul -r /tmp/patch -i %patchfile% 2>&1 | %tee% '%home%\OpenSSL.log'
   )
)
set PATH=%mingw%
if not exist done. (
   call ms\mingw32.bat 2>&1 | %tee% -a '%home%\OpenSSL.log'
)
echo. > done.

REM Berkeley DB
cd /d %home%\DB\build_unix
set PATH=%msys%
if not exist done. (
   sh.exe --login -c "cd '%cd%';../dist/configure --enable-mingw --enable-cxx" 2>&1 | %tee% '%home%\DB.log'
   make.exe 2>&1 | %tee% -a '%home%\DB.log'
)
echo. > done.

REM Boost
cd /d %home%\Boost
set PATH=%mingw%
if not exist done. (
   bjam\bjam.exe toolset=gcc --build-type=complete stage 2>&1 | %tee% '%home%\Boost.log'
)
echo. > done.

REM wxWidgets
cd /d %home%\wxWidgets\build\msw
set PATH=%mingw%
if not exist done. (
   mingw32-make.exe -f makefile.gcc 2>&1 | %tee% '%home%\wxWidgets.log'
)
echo. > done.

REM bitcoin
cd /d %home%
if exist s:\ subst s: /d
subst s: %home%
set patchfile=$bitcoin.patch
if not exist done. (
   if not exist %patchfile% (
      set PATH=%msys%
      openssl.exe enc -d -a < %patchfile%.gz.b64 | gzip.exe -dc > %patchfile%
      patch.exe -p1 -Nul -r /tmp/patch -i %patchfile% 2>&1 | %tee% '%home%\bitcoin.log'
   )
)
cd /d s:\
robocopy.exe /s /ndl /njh /njs \OpenSSL\outinc \OpenSSL\include
robocopy.exe /s /ndl /njh /njs \wxWidgets\lib\gcc_lib\mswd \wxWidgets\lib\vc_lib\mswd
if not exist \obj mkdir \obj
set PATH=%mingw%
if not exist done. (
   mingw32-make.exe bitcoin.exe -f makefile 2>&1 | %tee% -a '%home%\bitcoin.log'
)
subst s: /d

REM Prepare Distribution
cd /d %home%
if not exist dist mkdir dist
strip "bitcoin.exe" -o "dist\bitcoin.exe"
strip "OpenSSL\libeay32.dll" -o "dist\libeay32.dll"
strip "$mingw\bin\mingwm10.dll" -o "dist\mingwm10.dll"
echo. > done.

goto :end
:error
  echo ERROR Could not continue

:end
popd
set PATH=%oldpath%
endlocal
*/});

// Kinda sketchy, but "*.patch" files are very sensitive to CR/LF
var openssl_patch_gz_b64 = heredoc(function () {/*
H4sICEvkwl8CA29wZW5zc2wtT3BlblNTTF8wXzlfOGgucGF0Y2gApVRtb5swEP5c
fsVJE9Im5gRI09BomrKXqvvQlynVtI/IwUewakxkQ6Oq6n/fGei6tEm6rUj4zN1z
L9xztpB5DqwxfA3VCrW1il2SvLo6S8P0OE2KYWZuV3U1RGPcm3KlBtkOLFvxOitQ
bPXxGGP/kuMgDsOEhWMWJxCG09FkGh0CCydh6AVB8D8VUMQ4ZFHkIkbj6XgyDY8o
YkIRZzNgx8n7IwhoncBs5sEbqTPVCIQPfaphVtpB8ZEsqIXMPfCCm0oKOJnPU1Vx
kc6vPqW2NlIv7VtneQd3cO/BJqgrbBPnwcGdS5hrgTlcfj+5cH90cZmSlydeZAj1
Umq0Q0yX5eplcp7A9/HyBPo6Sp4H28dGMiYeAlqPd7HRNrIj5Jlx0eQ5mh3GrhBn
DLb0nFjc5mQs7zx68rfk1G2+rUR++/kXPJZ2WNJQrEfxYMHrl9q5id7H4ibydSQ+
i7WPw8hRGPXnaWawhD4qrGVdwHkXKDi9+AHc9gi2+6HeshUaBV8qnctlYxDaWsCP
wI/BH4F/CP4Y/CPwJ+AnXrAVXRcGubCgK2ayuBOHnRg7IQVyJwW2mEXu1ozb2kne
KTNeolKyxVlE0brbzq1wMzDDrKigyt010Y5z2I5z2DfDg9b+uZFKUFFUE4KSC8ON
ROpE32JW8msElsNj1/mAdB6TOdC1VhmFN6gggmVVV0CT6QXzk3OAneaHxKeo0fD6
IfXXszMLXAuQetXUf1YilFobviJaaKfpr50R+S3xTwpSV01NLoy0QNvhbyt3LtiW
/uhB3z2oP72EUmtbZdejmHZLIUex9wuF4A4hkwYAAA==
*/});

// Kinda sketchy, but "*.patch" files are very sensitive to CR/LF
var bitcoin_patch_gz_b64 = heredoc(function () {/*
H4sICALtw18CA2JpdGNvaW4tMC4xLjMucGF0Y2gAnZRrb9owFIY/D4n/cIZUKWni
4EDXFiokOsYm1K5Ipeu+VKpC4hSr4ES2s66t9t93ciFcRlBXE8XCx6+P857HDngY
Akmk9wRTrv2IC0Id12k3g6njx/HmIIk97c9YUARrhJCdqg8tSjuEusSl0Gp3aatL
KRB6SmnNsqy9a6K0RYnrklYHXNo9wqdTSPt9IEfusX0CVtrh2v1+Dbbba/3fsbQN
zoNAMqXAw96I1YsNV+Mvw/ur4c3P8fWFeVah4yEYqcThMXzsATXrNWvXvKq8acPU
RXbjUM+4srNNpCmtKsnCiwsJUw4XikltLLxHdh97XOYb+sb0BXs2zGI18wyaTZgG
j0DAj4RgvuaRgJD/rkjzZ8eOt8e2//tpscBwHMeE1zQaVPEjmN4DUBHdQVARWSHk
Zgi134LQSrvF0Ce6xpBLqWufglX0S4jSTy2+Fn1EczNbswJAKKMFjK4H4IkAh39h
NbhiECVS1Wtkicn9lD1woWeSeYFxk3WomTAW2EARtx+Xlyb0ergDs1ClLZaoCY3G
UMpIdqF6ERNCj89ZcCcaJTrN5n8mXqtlQcvNjGWfpnA6cAUieoKAhYnwdZnk3dss
kqxbu/J4oj2pIV9D7UEJ4efenL8wZ1ZR+LUZO5Bai5ZY0eMMK/oWrDb1+9BqUfsY
LHyfZFj5cw8vnMF5oqOvaMlZboPSnuZ+ekaVBvQQbofXk9H4Cnq4ZDut7MYMf+bJ
Q8ALa5JMb5nEWQ2I54lqpOaW3mZPpYMJ33MW8+AO3/LAuywrpXvdOu20M7/S/qQ8
iE1sSOA0ecihK4BZAngn3vZrlFf6Uvk53yoMvj+fx3G3OxYjwbVhrh+o7bl41FV6
jR4EBwrn2cti2auKmBuF2Ib8ki84Qh6B4uJhzrDgWF3hM4ixlgmiVa/9BfrlXJiE
BwAA
*/});

var closing_msg = heredoc(function () {/*
Follow-up Steps:

   You've now installed the tool-chain to build $bitcoin.  To perform
   the build you must complete the following steps.

   1. Disable your network - $bitcoin can not be allowed on the public
      network due to a hardfork that happened on version 0.8.1.  There is
      also an annoying IRC bot that will get your IP banned.
   2. Install MSYS - The MSYS installer has been placed in the in your
      archive folder at $archive.  To install it
      simply run the following commands from that directory:
         - MSYS-*.exe (the main MSYS installer).
         - msysDTK-*.exe (the MSYS dev-kit installer).
   3. Build historical bitcoin - A build script has been placed in the
      source directory at $msys\src\$bitcoin.  Simply CD to
      that directory and run the script named "buildAll.bat".
   4. Review logs - Your build will log its build progress to
      $msys\src\$bitcoin\*.log.  Errors are expected but should
      continue.  The process could take an hour or two.
   5. Gather your build - Your build binaries have been placed in
      $msys\src\$bitcoin\dist.  When run, it will automatically
      create the genesis block.  Just remember to ensure your offline!
*/});

function print(msg) {WScript.Echo(msg);}
function exit(rc) {WScript.Quit(rc);}
function getFile(node) {return node.url.split("/").pop();}
function sleep(sec) {WScript.Sleep(sec);}
function chDir(dir) {wso.CurrentDirectory = dir;}
function isDone(file) {return fso.FileExists(archive+"\\"+file);}

var RUNNING = 0;
var wso = new ActiveXObject("WScript.Shell");
var fso = new ActiveXObject("Scripting.FileSystemObject")
main();
