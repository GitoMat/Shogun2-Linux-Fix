.PHONY: all clean install

INSTALL_DIR     =   /opt/shogun2-fix
RES_LIB_NAME	=	libc_dlopen_mode
RES_LIB_NAME2	=	libc_mprotect
RES_LIB			=	$(RES_LIB_NAME).so
RES_LIB2		=	$(RES_LIB_NAME2).so
SRCS			=	\
	libc_dlopen_mode.c

CFLAGS	+=	-m32 -fpic -shared -flto -Wl,--version-script -Wl,version.map -Wl,--as-needed
CFLAGS2	+=	-m32 -shared

#
# Add `--save-temp` to collect more details about created shared library

all: $(RES_LIB) $(RES_LIB2)

$(RES_LIB): $(SRCS) version.map
	$(CC) $(CFLAGS) -o $@ $(SRCS)

$(RES_LIB2): 
	$(CC) $(CFLAGS2) -o $@ $(RES_LIB_NAME2).c

clean:
	$(RM)  *.so

install: all
	@sudo mkdir -p ${INSTALL_DIR}
	@sudo cp *.so ${INSTALL_DIR}

