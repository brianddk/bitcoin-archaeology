# bitcoin-archaeology
Building Old Code

Here's the basic process

### Install Windows

1. Create a Win2012 VM in VirtualBox
2. Install Win2012 in the VM
3. Disable HyperV on the Guest
4. Add shared-folders
5. Port forward RDP (3389) and WinRM (5985)
6. Punch through firewall for RDP

### Do the build

1. Run the powershell script (bitcoin-?.?.?.ps1)
2. Run the batch script (buildAll.cmd)
3. Turn off network due to old protocol
4. Test the build (bitcoin-?.?.?\dist\bitcoin.exe)

***

### TODO List

- [ ] Try it under Windows 2000 (requires rsync)
- [ ] Try it under Vista using Powershell 2.0
- [ ] Try it under Windows 7 using Powershell 2.0 or 3.0
- [x] Try it under Windows 2012 using Powershell 3.0
- [x] Build v0.1.0
- [x] Build v0.1.3
- [x] Build v0.1.5
- [ ] Build v0.2.0
- [ ] Build v0.3.0
- [ ] Build v0.3.13 last build before moving to TDM
- [ ] Debug hang on v0.1.0
- [ ] Debug hang on v0.2.0
- [ ] Cut binary releases of builds v0.1.0, v0.1.3 etc..

***

As I mentioned in my [other post](https://www.reddit.com/r/Bitcoin/comments/js9sxn/bitcoin_archaeology_building_old_code/), As a learning endeavor, I've been working on building the first 3 versions of bitcoin.exe.  Namely version 0.1.0, 0.1.3 and 0.1.5.  To try to be true to the original, I'm working on building up an environment as close to the original one used in October 2009.  Harder than it might seem.

Although it isn't known (by me), The two major versions of Windows that were available at this time Windows Vista (Longhorn) and Windows 7.  Not really wanting to buy a license for either of these, my choices are to use either archived beta's or jump a bit ahead or behind.  I decided to jump ahead to Windows 8 (2012) and use that as by build base.  Since I'm using the "Server Core" edition, it may be a bit foreign to most, but I find it works quite well.

Since I'm using an old OS, its best to run it in a virtual machine just to reduce the heartache of trying to find HW that will run the old SW.  I'm use VirtualBox which is available in many different host formats.

Once I get the OS up and running I install Perl (strawberry), GCC (MinGW) and Bash (MSYS).  From there it's pretty much just paint by numbers, though I'm still having trouble in the very last step.  Here's, hopefully, a very brief rundown of how to get it working

### Download the files

At the end of this article I have the links to all the files and their MD5 checksum.  They are all archives of one kind or another that have their own checksums baked in.  This is just so you can sanity check your downloads.  Files not OS or VM related will be pushed to the VM once we get it up and running.

### Building the VM

I used the default Windows 2012 settings for VirtualBox.  Though I did enable port forwarding for RDP (3389) and remote shell (5985).  I'd suggest also enabling shared folders to push over the downloads.  You will need to take care.  I'm running Hyper-V as my guest OS (yes inside a VM) since it's free.  To pull this off you have to disable the Hyper-V feature halfway through the install.

### Building OpenSSL

OpenSSL was the build that originally tripped me up.  Turns out it was a bad version of Perl I was using.  I switched to Strawberry Perl and everything cleared up.  I did have to give up on the optimizations Satoshi outlined in his original code, and just did a plain vanilla build of OpenSSL (disabling the assembler since I don't own one)

    set home=C:\msys\1.0\src\bitcoin-0.1.5
    set path=C:\MinGW\mingw32\bin;C:\MinGW\bin;C:\Perl58\bin;%path%
    set tee=C:\msys\1.0\bin\tee.exe
    cd /d %home%\OpenSSL
    call ms\mingw32.bat no-asm 2>&1 | %tee% '%home%\OpenSSL.log'

### Building Berkley

This looks a bit more tortured than it needs to be.  Basically I just need to launch a BASH shell to run the configure script.  That bit of extra Kung-Fu is just restoring the PWD.

    set home=C:\msys\1.0\src\bitcoin-0.1.5
    set path=C:\MinGW\mingw32\bin;C:\MinGW\bin;C:\msys\1.0\bin;%path%
    cd /d %home%\DB\build_unix
    sh --login -c "cd '%cd%';../dist/configure --enable-mingw --enable-cxx" 2>&1 | tee '%home%\DB.log'
    make.exe 2>&1 | tee -a '%home%\DB.log'

### Building wxWidgets

It's about as simple as you can get... which is why I'm perplexed that this build seems to have been the root of my current issue.  Hopefully I'll find root cause soon.

    set home=C:\msys\1.0\src\bitcoin-0.1.5
    set path=C:\MinGW\mingw32\bin;C:\MinGW\bin;C:\Perl58\bin;%path%
    set tee=C:\msys\1.0\bin\tee.exe
    cd /d %home%\wxWidgets\build\msw
    mingw32-make -f makefile.gcc 2>&1 | %tee% '%home%\wxWidgets.log'

### Building Boost

Buckle up.  Boost takes about two hours to build on my VM.  The build isn't perfect either.  Attempted about 4000 targets, skipped 56, and failed 96 of them.  Some of those targets were due to the fact that I didn't install a 64-bit cross-compiler, so I assumed they are expected.  The build requires bjam which is in my download list, but it is easy to miss.

    set home=C:\msys\1.0\src\bitcoin-0.1.5
    set path=C:\MinGW\mingw32\bin;C:\MinGW\bin;C:\Perl58\bin;%path%
    set tee=C:\msys\1.0\bin\tee.exe
    cd /d %home%\Boost
    bjam\bjam toolset=gcc --build-type=complete stage 2>&1 | %tee% '%home%\Boost.log'

### Building Bitcoin

Again... looks a bit complicated, but the shuffling of the subst command is analogous to a chroot command in linux.  It simply changes where the root directory is.  The bitcoin make file looks for the dependencies in the root directory.  This is just a way for me to keep them in a subfolder until it is time to build.  I doubt this is the cause of my failures, but I can move things around later I suppose.

#### Update

Found two errors in `Makefile` that I can workaround with the two `robocopy` commands now included.

    set home=C:\msys\1.0\src\bitcoin-0.1.5
    set path=C:\MinGW\mingw32\bin;C:\MinGW\bin;C:\Perl58\bin;%path%
    set tee=C:\msys\1.0\bin\tee.exe
    if exist s:\ subst s: /d
    subst s: %home%
    cd /d s:\
    robocopy /s /OpenSSL/outinc /OpenSSL/include
    robocopy /s /wxWidgets/lib/gcc_lib/mswd /wxWidgets/lib/vc_lib/mswd
    if not exist \obj mkdir \obj
    if not exist \out mkdir \out
    mingw32-make bitcoin.exe -f makefile 2>&1 | %tee% '%home%\bitcoin.log'
    copy \bitcoin.exe \out
    copy \OpenSSL\libeay32.dll \out
    copy C:\MinGW\bin\mingwm10.dll \out
    subst s: /d

### Final Failure

#### Update

Found two errors in `Makefile` that I can workaround with the two `robocopy` commands now included.  No more failures, the vintage `bitcoin.exe` is up and running.

~~Although I'm able to get all the dependencies to build, bitcoin.exe is still failing.  It starts with some errors on /wxWidgets, and just cascades from there.~~

    g++ -c -mthreads -O0 -w -Wno-invalid-offsetof -Wformat -g -D__WXDEBUG__ -DWIN32 -D__WXMSW__ -D_WINDOWS -DNOPCH -I"/boost" -I"/DB/build_unix" -I"/OpenSSL/include" -I"/wxWidgets/lib/vc_lib/mswd" -I"/wxWidgets/include" -o headers.h.gch headers.h
    In file included from /wxWidgets/include/wx/defs.h:21,
                     from /wxWidgets/include/wx/wx.h:15,
                     from headers.h:15:
    /wxWidgets/include/wx/platform.h:196:22: wx/setup.h: No such file or directory
    In file included from /wxWidgets/include/wx/platform.h:293,
                     from /wxWidgets/include/wx/defs.h:21,
                     from /wxWidgets/include/wx/wx.h:15,
                     from headers.h:15:
    /wxWidgets/include/wx/chkconf.h:103:9: #error "wxUSE_DYNLIB_CLASS must be defined."
    /wxWidgets/include/wx/chkconf.h:111:9: #error "wxUSE_EXCEPTIONS must be defined."
    /wxWidgets/include/wx/chkconf.h:119:9: #error "wxUSE_FILESYSTEM must be defined."
    /wxWidgets/include/wx/chkconf.h:127:9: #error "wxUSE_FS_ARCHIVE must be defined."


### Files Used

I do have the following archived, but you should do the same.  You never know when the maintainer will take the old copies down.  This happened with perl (ActivePerl) which now requires a membership to access old releases

| MD5 Checksum | URL | 
| :----- | :----- |
| ^(257ca8b8ea94ba6afb6417d7f8f6c6f4) | ^(https://www.microsoft.com/en-us/evalcenter/evaluate-hyper-v-server-2012) |
| ^(3eed9c1a02df46408c59444e5ee00b24) | ^(https://download.virtualbox.org/virtualbox/6.1.12/VirtualBox-6.1.12-139181-Win.exe) |
| ^(0b431b557399c1b3948c13c803a22c95) | ^(https://downloads.sourceforge.net/gnuwin32/zlib-1.2.3-bin.zip) |
| ^(a1155c41b1954a2f6da1014c7c1a1263) | ^(https://downloads.sourceforge.net/gnuwin32/bzip2-1.0.5-bin.zip) |
| ^(f2bd5a4ee39d9fc64b456d516f90afad) | ^(https://downloads.sourceforge.net/gnuwin32/libarchive-2.4.12-1-bin.zip) |
| ^(6bba3bd1bf510d152a42d0beeeefa14d) | ^(https://downloads.sourceforge.net/mingw/binutils-2.19.1-mingw32-bin.tar.gz) |
| ^(3be0d55e058699b615fa1d7389a8ce41) | ^(https://downloads.sourceforge.net/mingw/gcc-core-3.4.5-20051220-1.tar.gz) |
| ^(99059fbaa93fa1a29f5571967901e11f) | ^(https://downloads.sourceforge.net/mingw/gcc-g++-3.4.5-20051220-1.tar.gz) |
| ^(f24d63744af66b54547223bd5476b8f0) | ^(https://downloads.sourceforge.net/mingw/mingwrt-3.15.2-mingw32-dev.tar.gz) |
| ^(688866a2de8d17adb50c54a2a1edbab4) | ^(https://downloads.sourceforge.net/mingw/mingwrt-3.15.2-mingw32-dll.tar.gz) |
| ^(a50fff6bc1e1542451722e2650cb53b4) | ^(https://downloads.sourceforge.net/mingw/w32api-3.13-mingw32-dev.tar.gz) |
| ^(8692c3c6967f7530a2ad562fe69781d2) | ^(https://downloads.sourceforge.net/mingw/mingw32-make-3.81-20080326-2.tar.gz) |
| ^(cf95067cc749b00bf5b81deb40a8e16c) | ^(https://downloads.sourceforge.net/mingw/MSYS-1.0.11.exe) |
| ^(f7aeebb16dc3b0f19b018506ed743fbb) | ^(https://downloads.sourceforge.net/mingw/msysDTK-1.0.1.exe) |
| ^(79b4148f26fb3a7e7c30c8956b193880) | ^(http://strawberryperl.com/download/5.8.8/strawberry-perl-5.8.8.2.zip) |
| ^(4959877a1dde3125cc627b1ed16b5916) | ^(https://github.com/bitcoin/bitcoin/archive/v0.1.5.zip) |
| ^(33eda5d65838279f4dfbb369b7c75fbd) | ^(https://downloads.sourceforge.net/wxwindows/wxWidgets-2.8.11.zip) |
| ^(368d680fe87f395f9d161a45d6248f4d) | ^(https://github.com/openssl/openssl/archive/OpenSSL_0_9_8h.zip) |
| ^(0582ef9de0cbc9d3ad89598ded6b56b5) | ^(https://download.oracle.com/berkeley-db/db-4.7.25.NC.zip) |
| ^(ac4fcb435257e1c60ec1d06773bbdc18) | ^(https://downloads.sourceforge.net/boost/1.37.0/boost_1_37_0.zip) |
| ^(72615486b39b0b6f5dfa91df531b7f7e) | ^(https://downloads.sourceforge.net/boost/boost-jam/boost-jam-3.1.17-1-ntx86.zip) |