.PHONY: all clean

PRIV_DIR = ${MIX_APP_PATH}/priv
NIF_SO = ${PRIV_DIR}/ldns_nif.so

CFLAGS = -g -O3 -std=c99 -fPIC -pedantic -Wall -Wextra -I${ERTS_INCLUDE_DIR} -I/usr/local/include
LDFLAGS = -shared -L/usr/local/lib -lldns

all: ${NIF_SO}

${NIF_SO}: c_src/ldns_nif.c
	${CC} ${CFLAGS} $< ${LDFLAGS} -o $@

clean:
	rm -f ${NIF_SO}
