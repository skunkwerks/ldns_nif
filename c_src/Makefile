.PHONY: all clean

PRIV_DIR = ${MIX_APP_PATH}/priv
NIF_SO = ${PRIV_DIR}/ldns_nif.so

CFLAGS = -I$$(brew --prefix)/include -g -O3 -std=c11 -fPIC -pedantic -Wall -Wextra -I${ERTS_INCLUDE_DIR} -I/usr/local/include -undefined dynamic_lookup -flat_namespace
LDFLAGS = -L$$(brew --prefix)/lib -shared -L/usr/local/lib -lldns -lc

all: ${NIF_SO}

${PRIV_DIR}:
	mkdir -p $@

${NIF_SO}: ldns_nif.c ${PRIV_DIR}
	${CC} ${CFLAGS} ldns_nif.c ${LDFLAGS} -o $@

clean:
	rm -f ${NIF_SO}
