#include <erl_nif.h>
#include <ldns/ldns.h>
#include <string.h>

static ERL_NIF_TERM validate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    ErlNifBinary zone_binary;
    if (!enif_inspect_binary(env, argv[0], &zone_binary)) {
        return enif_make_badarg(env);
    }

    ldns_zone* zone = NULL;
    ldns_status status;
    int line_nr = 0;

    // Create a buffer with the zone data and null terminate it
    char* zone_str = (char*)enif_alloc(zone_binary.size + 1);
    if (!zone_str) {
        return enif_make_tuple2(env,
            enif_make_atom(env, "error"),
            enif_make_string(env, "Memory allocation failed", ERL_NIF_LATIN1));
    }
    memcpy(zone_str, zone_binary.data, zone_binary.size);
    zone_str[zone_binary.size] = '\0';

    FILE* fp = fmemopen(zone_str, zone_binary.size + 1, "r");
    if (!fp) {
        enif_free(zone_str);
        return enif_make_tuple2(env,
            enif_make_atom(env, "error"),
            enif_make_string(env, "Failed to create memory stream", ERL_NIF_LATIN1));
    }

    status = ldns_zone_new_frm_fp_l(&zone, fp, NULL, 0, LDNS_RR_CLASS_IN, &line_nr);

    ERL_NIF_TERM result;
    if (status != LDNS_STATUS_OK) {
        const char* error_str = ldns_get_errorstr_by_id(status);
        unsigned error_len = strlen(error_str);
        ErlNifBinary error_bin;

        if (!enif_alloc_binary(error_len, &error_bin)) {
            result = enif_make_tuple2(env,
                enif_make_atom(env, "error"),
                enif_make_atom(env, "memory_error"));
            goto cleanup;
        }

        memcpy(error_bin.data, error_str, error_len);

        const char* status_str;
        switch (status) {
            case LDNS_STATUS_SYNTAX_ERR:
            case LDNS_STATUS_SYNTAX_TTL:
            case LDNS_STATUS_SYNTAX_DNAME_ERR:
            case LDNS_STATUS_SYNTAX_RDATA_ERR:
            case LDNS_STATUS_INVALID_INT:
                status_str = "rdata_error";
                break;
            default:
                status_str = "unknown_error";
        }

        result = enif_make_tuple4(env,
            enif_make_atom(env, "error"),
            enif_make_atom(env, status_str),
            enif_make_int(env, line_nr),
            enif_make_binary(env, &error_bin));
    } else {
        result = enif_make_atom(env, "ok");
    }

cleanup:
    if (zone) {
        ldns_zone_free(zone);
    }
    fclose(fp);
    enif_free(zone_str);

    return result;
}

static ErlNifFunc nif_funcs[] = {
    {"validate", 1, validate, ERL_NIF_DIRTY_JOB_CPU_BOUND}
};

ERL_NIF_INIT(Elixir.LDNS, nif_funcs, NULL, NULL, NULL, NULL)
