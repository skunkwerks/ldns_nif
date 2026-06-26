#define _POSIX_C_SOURCE 200809L
#include <erl_nif.h>
#include <ldns/ldns.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static ERL_NIF_TERM
make_binary_string(ErlNifEnv *env, const char *str)
{
	size_t len = strlen(str);
	ErlNifBinary bin;
	if (!enif_alloc_binary(len, &bin))
		return enif_make_atom(env, "nil");
	memcpy(bin.data, str, len);
	return enif_make_binary(env, &bin);
}

static ERL_NIF_TERM
make_rdf_string(ErlNifEnv *env, ldns_rdf *rdf)
{
	char *str = ldns_rdf2str(rdf);
	if (!str)
		return enif_make_atom(env, "nil");
	ERL_NIF_TERM term = make_binary_string(env, str);
	free(str);
	return term;
}

static ERL_NIF_TERM
make_trimmed_rdf_string(ErlNifEnv *env, ldns_rdf *rdf)
{
	char *str = ldns_rdf2str(rdf);
	if (!str)
		return enif_make_atom(env, "nil");
	size_t len = strlen(str);
	while (len > 0 && str[len - 1] == ' ')
		str[--len] = '\0';
	ERL_NIF_TERM term = make_binary_string(env, str);
	free(str);
	return term;
}

static ERL_NIF_TERM
make_unquoted_rdf_string(ErlNifEnv *env, ldns_rdf *rdf)
{
	char *str = ldns_rdf2str(rdf);
	if (!str)
		return enif_make_atom(env, "nil");
	size_t len = strlen(str);
	ERL_NIF_TERM term;
	if (len >= 2 && str[0] == '"' && str[len - 1] == '"') {
		str[len - 1] = '\0';
		term = make_binary_string(env, str + 1);
	} else {
		term = make_binary_string(env, str);
	}
	free(str);
	return term;
}

static ERL_NIF_TERM
make_dname_string(ErlNifEnv *env, ldns_rdf *rdf)
{
	char *str = ldns_rdf2str(rdf);
	if (!str)
		return enif_make_atom(env, "nil");
	size_t len = strlen(str);
	if (len > 0 && str[len - 1] == '.')
		str[len - 1] = '\0';
	ERL_NIF_TERM term = make_binary_string(env, str);
	free(str);
	return term;
}

/*
 * Build the type-specific data map for a resource record.
 * Returns 1 on success (result stored in *out), 0 on error
 * (error term stored in *out).
 */
static int
make_rr_data(ErlNifEnv *env, ldns_rr *rr, ERL_NIF_TERM *out)
{
	ldns_rr_type type = ldns_rr_get_type(rr);
	ERL_NIF_TERM data;

	switch (type) {
	case LDNS_RR_TYPE_SOA: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "mname"),
		    enif_make_atom(env, "rname"),
		    enif_make_atom(env, "serial"),
		    enif_make_atom(env, "refresh"),
		    enif_make_atom(env, "retry"),
		    enif_make_atom(env, "expire"),
		    enif_make_atom(env, "minimum"),
		};
		ERL_NIF_TERM vals[] = {
		    make_dname_string(env, ldns_rr_rdf(rr, 0)),
		    make_dname_string(env, ldns_rr_rdf(rr, 1)),
		    enif_make_uint(env, ldns_rdf2native_int32(ldns_rr_rdf(rr, 2))),
		    enif_make_uint(env, ldns_rdf2native_int32(ldns_rr_rdf(rr, 3))),
		    enif_make_uint(env, ldns_rdf2native_int32(ldns_rr_rdf(rr, 4))),
		    enif_make_uint(env, ldns_rdf2native_int32(ldns_rr_rdf(rr, 5))),
		    enif_make_uint(env, ldns_rdf2native_int32(ldns_rr_rdf(rr, 6))),
		};
		enif_make_map_from_arrays(env, keys, vals, 7, &data);
		break;
	}
	case LDNS_RR_TYPE_A: {
		ERL_NIF_TERM keys[] = { enif_make_atom(env, "ip") };
		ERL_NIF_TERM vals[] = { make_rdf_string(env, ldns_rr_rdf(rr, 0)) };
		enif_make_map_from_arrays(env, keys, vals, 1, &data);
		break;
	}
	case LDNS_RR_TYPE_AAAA: {
		ERL_NIF_TERM keys[] = { enif_make_atom(env, "ip") };
		ERL_NIF_TERM vals[] = { make_rdf_string(env, ldns_rr_rdf(rr, 0)) };
		enif_make_map_from_arrays(env, keys, vals, 1, &data);
		break;
	}
	case LDNS_RR_TYPE_NS: {
		ERL_NIF_TERM keys[] = { enif_make_atom(env, "dname") };
		ERL_NIF_TERM vals[] = { make_dname_string(env, ldns_rr_rdf(rr, 0)) };
		enif_make_map_from_arrays(env, keys, vals, 1, &data);
		break;
	}
	case LDNS_RR_TYPE_PTR: {
		ERL_NIF_TERM keys[] = { enif_make_atom(env, "dname") };
		ERL_NIF_TERM vals[] = { make_dname_string(env, ldns_rr_rdf(rr, 0)) };
		enif_make_map_from_arrays(env, keys, vals, 1, &data);
		break;
	}
	case LDNS_RR_TYPE_CNAME: {
		ERL_NIF_TERM keys[] = { enif_make_atom(env, "dname") };
		ERL_NIF_TERM vals[] = { make_dname_string(env, ldns_rr_rdf(rr, 0)) };
		enif_make_map_from_arrays(env, keys, vals, 1, &data);
		break;
	}
	case LDNS_RR_TYPE_DNAME: {
		ERL_NIF_TERM keys[] = { enif_make_atom(env, "dname") };
		ERL_NIF_TERM vals[] = { make_dname_string(env, ldns_rr_rdf(rr, 0)) };
		enif_make_map_from_arrays(env, keys, vals, 1, &data);
		break;
	}
	case LDNS_RR_TYPE_MX: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "preference"),
		    enif_make_atom(env, "exchange"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 0))),
		    make_dname_string(env, ldns_rr_rdf(rr, 1)),
		};
		enif_make_map_from_arrays(env, keys, vals, 2, &data);
		break;
	}
	case LDNS_RR_TYPE_TXT: {
		char *str = ldns_rdf2str(ldns_rr_rdf(rr, 0));
		if (str) {
			size_t len = strlen(str);
			if (len >= 2 && str[0] == '"' && str[len - 1] == '"') {
				str[len - 1] = '\0';
				ERL_NIF_TERM keys[] = { enif_make_atom(env, "txt") };
				ERL_NIF_TERM vals[] = { make_binary_string(env, str + 1) };
				enif_make_map_from_arrays(env, keys, vals, 1, &data);
			} else {
				ERL_NIF_TERM keys[] = { enif_make_atom(env, "txt") };
				ERL_NIF_TERM vals[] = { make_binary_string(env, str) };
				enif_make_map_from_arrays(env, keys, vals, 1, &data);
			}
			free(str);
		} else {
			data = enif_make_new_map(env);
		}
		break;
	}
	case LDNS_RR_TYPE_SRV: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "priority"),
		    enif_make_atom(env, "weight"),
		    enif_make_atom(env, "port"),
		    enif_make_atom(env, "target"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 0))),
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 1))),
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 2))),
		    make_dname_string(env, ldns_rr_rdf(rr, 3)),
		};
		enif_make_map_from_arrays(env, keys, vals, 4, &data);
		break;
	}
	case LDNS_RR_TYPE_NAPTR: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "order"),
		    enif_make_atom(env, "preference"),
		    enif_make_atom(env, "flags"),
		    enif_make_atom(env, "service"),
		    enif_make_atom(env, "regexp"),
		    enif_make_atom(env, "replacement"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 0))),
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 1))),
		    make_unquoted_rdf_string(env, ldns_rr_rdf(rr, 2)),
		    make_unquoted_rdf_string(env, ldns_rr_rdf(rr, 3)),
		    make_unquoted_rdf_string(env, ldns_rr_rdf(rr, 4)),
		    make_dname_string(env, ldns_rr_rdf(rr, 5)),
		};
		enif_make_map_from_arrays(env, keys, vals, 6, &data);
		break;
	}
	case LDNS_RR_TYPE_DS: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "key_tag"),
		    enif_make_atom(env, "algorithm"),
		    enif_make_atom(env, "digest_type"),
		    enif_make_atom(env, "digest"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 0))),
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 1))),
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 2))),
		    make_rdf_string(env, ldns_rr_rdf(rr, 3)),
		};
		enif_make_map_from_arrays(env, keys, vals, 4, &data);
		break;
	}
	case LDNS_RR_TYPE_SSHFP: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "alg"),
		    enif_make_atom(env, "fp_type"),
		    enif_make_atom(env, "fp"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 0))),
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 1))),
		    make_rdf_string(env, ldns_rr_rdf(rr, 2)),
		};
		enif_make_map_from_arrays(env, keys, vals, 3, &data);
		break;
	}
	case LDNS_RR_TYPE_RRSIG: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "type_covered"),
		    enif_make_atom(env, "alg"),
		    enif_make_atom(env, "labels"),
		    enif_make_atom(env, "original_ttl"),
		    enif_make_atom(env, "expiration"),
		    enif_make_atom(env, "inception"),
		    enif_make_atom(env, "key_tag"),
		    enif_make_atom(env, "signers_name"),
		    enif_make_atom(env, "signature"),
		};
		ERL_NIF_TERM vals[] = {
		    make_rdf_string(env, ldns_rr_rdf(rr, 0)),
		    make_rdf_string(env, ldns_rr_rdf(rr, 1)),
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 2))),
		    enif_make_uint(env, ldns_rdf2native_int32(ldns_rr_rdf(rr, 3))),
		    make_rdf_string(env, ldns_rr_rdf(rr, 4)),
		    make_rdf_string(env, ldns_rr_rdf(rr, 5)),
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 6))),
		    make_dname_string(env, ldns_rr_rdf(rr, 7)),
		    make_rdf_string(env, ldns_rr_rdf(rr, 8)),
		};
		enif_make_map_from_arrays(env, keys, vals, 9, &data);
		break;
	}
	case LDNS_RR_TYPE_NSEC: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "next_domain"),
		    enif_make_atom(env, "types"),
		};
		ERL_NIF_TERM vals[] = {
		    make_dname_string(env, ldns_rr_rdf(rr, 0)),
		    make_trimmed_rdf_string(env, ldns_rr_rdf(rr, 1)),
		};
		enif_make_map_from_arrays(env, keys, vals, 2, &data);
		break;
	}
	case LDNS_RR_TYPE_NSEC3: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "hash_algorithm"),
		    enif_make_atom(env, "flags"),
		    enif_make_atom(env, "iterations"),
		    enif_make_atom(env, "salt"),
		    enif_make_atom(env, "next_hashed_owner"),
		    enif_make_atom(env, "types"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 0))),
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 1))),
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 2))),
		    make_trimmed_rdf_string(env, ldns_rr_rdf(rr, 3)),
		    make_rdf_string(env, ldns_rr_rdf(rr, 4)),
		    make_trimmed_rdf_string(env, ldns_rr_rdf(rr, 5)),
		};
		enif_make_map_from_arrays(env, keys, vals, 6, &data);
		break;
	}
	case LDNS_RR_TYPE_NSEC3PARAM: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "hash_algorithm"),
		    enif_make_atom(env, "flags"),
		    enif_make_atom(env, "iterations"),
		    enif_make_atom(env, "salt"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 0))),
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 1))),
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 2))),
		    make_trimmed_rdf_string(env, ldns_rr_rdf(rr, 3)),
		};
		enif_make_map_from_arrays(env, keys, vals, 4, &data);
		break;
	}
	case LDNS_RR_TYPE_DNSKEY: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "flags"),
		    enif_make_atom(env, "protocol"),
		    enif_make_atom(env, "alg"),
		    enif_make_atom(env, "public_key"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int16(ldns_rr_rdf(rr, 0))),
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 1))),
		    make_rdf_string(env, ldns_rr_rdf(rr, 2)),
		    make_rdf_string(env, ldns_rr_rdf(rr, 3)),
		};
		enif_make_map_from_arrays(env, keys, vals, 4, &data);
		break;
	}
	case LDNS_RR_TYPE_TLSA: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "usage"),
		    enif_make_atom(env, "selector"),
		    enif_make_atom(env, "matching_type"),
		    enif_make_atom(env, "certificate_data"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 0))),
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 1))),
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 2))),
		    make_rdf_string(env, ldns_rr_rdf(rr, 3)),
		};
		enif_make_map_from_arrays(env, keys, vals, 4, &data);
		break;
	}
	case LDNS_RR_TYPE_HINFO: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "cpu"),
		    enif_make_atom(env, "os"),
		};
		ERL_NIF_TERM vals[] = {
		    make_unquoted_rdf_string(env, ldns_rr_rdf(rr, 0)),
		    make_unquoted_rdf_string(env, ldns_rr_rdf(rr, 1)),
		};
		enif_make_map_from_arrays(env, keys, vals, 2, &data);
		break;
	}
	case LDNS_RR_TYPE_SPF: {
		char *str = ldns_rdf2str(ldns_rr_rdf(rr, 0));
		if (str) {
			size_t len = strlen(str);
			if (len >= 2 && str[0] == '"' && str[len - 1] == '"') {
				str[len - 1] = '\0';
				ERL_NIF_TERM keys[] = { enif_make_atom(env, "txt") };
				ERL_NIF_TERM vals[] = { make_binary_string(env, str + 1) };
				enif_make_map_from_arrays(env, keys, vals, 1, &data);
			} else {
				ERL_NIF_TERM keys[] = { enif_make_atom(env, "txt") };
				ERL_NIF_TERM vals[] = { make_binary_string(env, str) };
				enif_make_map_from_arrays(env, keys, vals, 1, &data);
			}
			free(str);
		} else {
			data = enif_make_new_map(env);
		}
		break;
	}
	case LDNS_RR_TYPE_LOC: {
		ERL_NIF_TERM keys[] = { enif_make_atom(env, "loc") };
		ERL_NIF_TERM vals[] = { make_rdf_string(env, ldns_rr_rdf(rr, 0)) };
		enif_make_map_from_arrays(env, keys, vals, 1, &data);
		break;
	}
	case LDNS_RR_TYPE_CAA: {
		ERL_NIF_TERM keys[] = {
		    enif_make_atom(env, "flags"),
		    enif_make_atom(env, "tag"),
		    enif_make_atom(env, "value"),
		};
		ERL_NIF_TERM vals[] = {
		    enif_make_uint(env, ldns_rdf2native_int8(ldns_rr_rdf(rr, 0))),
		    make_rdf_string(env, ldns_rr_rdf(rr, 1)),
		    make_rdf_string(env, ldns_rr_rdf(rr, 2)),
		};
		enif_make_map_from_arrays(env, keys, vals, 3, &data);
		break;
	}
	default: {
		char *type_str = ldns_rr_type2str(type);
		char *owner_str = ldns_rdf2str(ldns_rr_owner(rr));
		char msg[256];
		snprintf(msg, sizeof(msg),
		    "Unsupported RR type '%s' for name '%s'",
		    type_str ? type_str : "unknown",
		    owner_str ? owner_str : "unknown");
		free(type_str);
		free(owner_str);

		size_t msg_len = strlen(msg);
		ErlNifBinary msg_bin;
		if (!enif_alloc_binary(msg_len, &msg_bin)) {
			*out = enif_make_tuple2(env,
			    enif_make_atom(env, "error"),
			    enif_make_atom(env, "memory_error"));
			return 0;
		}
		memcpy(msg_bin.data, msg, msg_len);

		*out = enif_make_tuple3(env,
		    enif_make_atom(env, "error"),
		    enif_make_atom(env, "unsupported_rr_type"),
		    enif_make_binary(env, &msg_bin));
		return 0;
	}
	}

	*out = data;
	return 1;
}

static int
make_rr_term(ErlNifEnv *env, ldns_rr *rr, ERL_NIF_TERM *out)
{
	ERL_NIF_TERM data;
	if (!make_rr_data(env, rr, &data)) {
		*out = data;
		return 0;
	}

	ldns_rr_type type = ldns_rr_get_type(rr);
	char *type_str = ldns_rr_type2str(type);

	ERL_NIF_TERM keys[] = {
	    enif_make_atom(env, "name"),
	    enif_make_atom(env, "type"),
	    enif_make_atom(env, "ttl"),
	    enif_make_atom(env, "data"),
	};
	ERL_NIF_TERM vals[] = {
	    make_dname_string(env, ldns_rr_owner(rr)),
	    make_binary_string(env, type_str),
	    enif_make_uint(env, ldns_rr_ttl(rr)),
	    data,
	};

	ERL_NIF_TERM map;
	enif_make_map_from_arrays(env, keys, vals, 4, &map);

	free(type_str);
	*out = map;
	return 1;
}

static ldns_zone *
parse_zone(ErlNifEnv *env, const ERL_NIF_TERM *argv, char **zone_str_out,
    FILE **fp_out, int *line_nr)
{
	ErlNifBinary zone_binary;
	if (!enif_inspect_binary(env, argv[0], &zone_binary))
		return NULL;

	char *zone_str = (char *)enif_alloc(zone_binary.size + 1);
	if (!zone_str)
		return NULL;
	memcpy(zone_str, zone_binary.data, zone_binary.size);
	zone_str[zone_binary.size] = '\0';

	FILE *fp = fmemopen(zone_str, zone_binary.size + 1, "r");
	if (!fp) {
		enif_free(zone_str);
		return NULL;
	}

	ldns_zone *zone = NULL;
	*line_nr = 0;
	ldns_status status = ldns_zone_new_frm_fp_l(&zone, fp, NULL, 0,
	    LDNS_RR_CLASS_IN, line_nr);

	if (status != LDNS_STATUS_OK) {
		if (zone)
			ldns_zone_free(zone);
		fclose(fp);
		enif_free(zone_str);
		return NULL;
	}

	*zone_str_out = zone_str;
	*fp_out = fp;
	return zone;
}

static ERL_NIF_TERM
zone_validate(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	(void)argc;
	ErlNifBinary zone_binary;
	if (!enif_inspect_binary(env, argv[0], &zone_binary)) {
		return enif_make_badarg(env);
	}

	ldns_zone *zone = NULL;
	ldns_status status;
	int line_nr = 0;

	char *zone_str = (char *)enif_alloc(zone_binary.size + 1);
	if (!zone_str) {
		return enif_make_tuple2(env, enif_make_atom(env, "error"),
		    enif_make_string(env, "Memory allocation failed",
			ERL_NIF_LATIN1));
	}
	memcpy(zone_str, zone_binary.data, zone_binary.size);
	zone_str[zone_binary.size] = '\0';

	FILE *fp = fmemopen(zone_str, zone_binary.size + 1, "r");
	if (!fp) {
		enif_free(zone_str);
		return enif_make_tuple2(env, enif_make_atom(env, "error"),
		    enif_make_string(env, "Failed to create memory stream",
			ERL_NIF_LATIN1));
	}

	status = ldns_zone_new_frm_fp_l(&zone, fp, NULL, 0, LDNS_RR_CLASS_IN,
	    &line_nr);

	ERL_NIF_TERM result;
	if (status != LDNS_STATUS_OK) {
		const char *error_str = ldns_get_errorstr_by_id(status);
		unsigned error_len = strlen(error_str);
		ErlNifBinary error_bin;

		if (!enif_alloc_binary(error_len, &error_bin)) {
			result = enif_make_tuple2(env,
			    enif_make_atom(env, "error"),
			    enif_make_atom(env, "memory_error"));
			goto cleanup;
		}

		memcpy(error_bin.data, error_str, error_len);

		const char *status_str;
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

		result = enif_make_tuple4(env, enif_make_atom(env, "error"),
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

static ERL_NIF_TERM
zone_to_map(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	(void)argc;
	char *zone_str = NULL;
	FILE *fp = NULL;
	int line_nr = 0;

	ldns_zone *zone = parse_zone(env, argv, &zone_str, &fp, &line_nr);
	if (!zone) {
		return enif_make_tuple2(env, enif_make_atom(env, "error"),
		    enif_make_atom(env, "parse_failed"));
	}

	ldns_rr *soa = ldns_zone_soa(zone);
	ldns_rr_list *rrs = ldns_zone_rrs(zone);

	size_t rr_count = rrs ? ldns_rr_list_rr_count(rrs) : 0;
	size_t total = (soa ? 1 : 0) + rr_count;

	ERL_NIF_TERM *record_terms = enif_alloc(sizeof(ERL_NIF_TERM) * (total > 0 ? total : 1));
	if (!record_terms) {
		ldns_zone_free(zone);
		fclose(fp);
		enif_free(zone_str);
		return enif_make_tuple2(env, enif_make_atom(env, "error"),
		    enif_make_atom(env, "memory_error"));
	}

	size_t idx = 0;
	ERL_NIF_TERM rr_result;

	if (soa) {
		if (!make_rr_term(env, soa, &rr_result)) {
			enif_free(record_terms);
			ldns_zone_free(zone);
			fclose(fp);
			enif_free(zone_str);
			return rr_result;
		}
		record_terms[idx++] = rr_result;
	}
	for (size_t i = 0; i < rr_count; i++) {
		if (!make_rr_term(env, ldns_rr_list_rr(rrs, i), &rr_result)) {
			enif_free(record_terms);
			ldns_zone_free(zone);
			fclose(fp);
			enif_free(zone_str);
			return rr_result;
		}
		record_terms[idx++] = rr_result;
	}

	ERL_NIF_TERM records_list = enif_make_list_from_array(env, record_terms, idx);

	ERL_NIF_TERM zone_name;
	if (soa) {
		zone_name = make_dname_string(env, ldns_rr_owner(soa));
	} else if (rr_count > 0) {
		zone_name = make_dname_string(env, ldns_rr_owner(ldns_rr_list_rr(rrs, 0)));
	} else {
		zone_name = make_binary_string(env, "");
	}

	ERL_NIF_TERM map_keys[] = {
	    enif_make_atom(env, "name"),
	    enif_make_atom(env, "records"),
	};
	ERL_NIF_TERM map_vals[] = {
	    zone_name,
	    records_list,
	};
	ERL_NIF_TERM result_map;
	enif_make_map_from_arrays(env, map_keys, map_vals, 2, &result_map);

	enif_free(record_terms);
	ldns_zone_free(zone);
	fclose(fp);
	enif_free(zone_str);

	return enif_make_tuple2(env, enif_make_atom(env, "ok"), result_map);
}

static ErlNifFunc nif_funcs[] = {
    { "zone_validate", 1, zone_validate, ERL_NIF_DIRTY_JOB_CPU_BOUND },
    { "zone_to_map", 1, zone_to_map, ERL_NIF_DIRTY_JOB_CPU_BOUND },
};

ERL_NIF_INIT(Elixir.LDNS, nif_funcs, NULL, NULL, NULL, NULL)
