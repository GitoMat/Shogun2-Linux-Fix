# General

Small shared libraries to fix glibc compatibility issues to Steam's Shogun 2 game
for Ubuntu 23.04, 23.10, 24.04, 24.10, 25.04 (and above I hope). This adds a second fix I found on 
ProtonDB to the one from the forked repository (which was created for XCOM 2).:wq

# Prerequisites

Install basic build tools:

```sudo apt install build-essential gcc-multilib```

# Usage

Build the 2 shared libraries

```make clean install```

This installs the libraries in `/opt/shogun2-fix` (requires root), you can also 
just build them with `make clean all` and adapt the paths to a location of
your choosing.

Then add the following to the Launch Options in Steam:

```LD_PRELOAD=/opt/shogun2-fix/libc_mprotect.so:/opt/shogun2-fix/libc_dlopen_mode.so %command%```

# Additonal problems

Not sure when/how this was broken, but I also had to add the following to 
line 170 in the `Shogun2.sh` script in the game installation directory:

```export LD_LIBRARY_PATH="${GAMEROOT}/${FERAL_LIB_PATH}:${LD_LIBRARY_PATH}"```

# Alternative startup script

Instead of altering the `Shogun.sh` script and setting the launch options
you can also copy over the version from this repository where I already made
both changes.

# Known issues (from forked project)

Unfortunately space symbols in the path to `libc_dlopen_mode.so` library
are not supported by `Steam/steamapps/common/XCOM 2/XCOM2WotC/XCOM2WotC.sh`
script out of the box. I am quite lazy to look for a solution as i am happy
enough with given fix.

# Credits

- The libc_dlopen_mode fix is from user vkc-1974 in the forked repository
- The libc_mprotect fix was posted by PsychoPewPew on https://www.protondb.com/app/34330
