#include <erl_nif.h>
#include <ldns/ldns.h>
#include <string.h>

static ERL_NIF_TERM
validate(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary zone_binary;
	if (!enif_inspect_binary(env, argv[0], &zone_binary)) {
		return enif_make_badarg(env);
	}

	ldns_zone *zone = NULL;
	ldns_status status;
	int line_nr = 0;

	// ensure our zone buffer is null-terminated
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
to_map(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
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
		result = enif_make_tuple2(env, enif_make_atom(env, "error"),
		    enif_make_string(env, error_str, ERL_NIF_LATIN1));
	} else {
		// create an empty zone map
		ERL_NIF_TERM map = enif_make_new_map(env);
		ldns_rr *soa = ldns_zone_soa(zone);

		if (soa) {
			// fetch zone name
			char *owner = ldns_rdf2str(ldns_rr_owner(soa));
			ERL_NIF_TERM name_term = enif_make_string(env, owner,
			    ERL_NIF_LATIN1);
			enif_make_map_put(env, map, enif_make_atom(env, "name"),
			    name_term, &map);

			// make a list to hold all records
			ERL_NIF_TERM records_array = enif_make_list(env, 0);
			ERL_NIF_TERM soa_map = enif_make_new_map(env);
			enif_make_map_put(env, soa_map,
			    enif_make_atom(env, "name"), name_term, &soa_map);
			enif_make_map_put(env, soa_map,
			    enif_make_atom(env, "type"),
			    enif_make_string(env, "SOA", ERL_NIF_LATIN1),
			    &soa_map);
			enif_make_map_put(env, soa_map,
			    enif_make_atom(env, "ttl"),
			    enif_make_uint64(env, ldns_rr_ttl(soa)), &soa_map);

			ERL_NIF_TERM soa_data = enif_make_new_map(env);

			char *mname = ldns_rdf2str(ldns_rr_rdf(soa, 0));
			char *rname = ldns_rdf2str(ldns_rr_rdf(soa, 1));

			enif_make_map_put(env, soa_data,
			    enif_make_atom(env, "mname"),
			    enif_make_string(env, mname, ERL_NIF_LATIN1),
			    &soa_data);
			enif_make_map_put(env, soa_data,
			    enif_make_atom(env, "rname"),
			    enif_make_string(env, rname, ERL_NIF_LATIN1),
			    &soa_data);
			enif_make_map_put(env, soa_data,
			    enif_make_atom(env, "serial"),
			    enif_make_uint64(env,
				ldns_rdf2native_int32(ldns_rr_rdf(soa, 2))),
			    &soa_data);
			enif_make_map_put(env, soa_data,
			    enif_make_atom(env, "refresh"),
			    enif_make_uint64(env,
				ldns_rdf2native_int32(ldns_rr_rdf(soa, 3))),
			    &soa_data);
			enif_make_map_put(env, soa_data,
			    enif_make_atom(env, "retry"),
			    enif_make_uint64(env,
				ldns_rdf2native_int32(ldns_rr_rdf(soa, 4))),
			    &soa_data);
			enif_make_map_put(env, soa_data,
			    enif_make_atom(env, "expire"),
			    enif_make_uint64(env,
				ldns_rdf2native_int32(ldns_rr_rdf(soa, 5))),
			    &soa_data);
			enif_make_map_put(env, soa_data,
			    enif_make_atom(env, "minimum"),
			    enif_make_uint64(env,
				ldns_rdf2native_int32(ldns_rr_rdf(soa, 6))),
			    &soa_data);

			free(mname);
			free(rname);

			// stuff it in the SOA RR
			enif_make_map_put(env, soa_map,
			    enif_make_atom(env, "data"), soa_data, &soa_map);

			// stuff it in the records list
			records_array = enif_make_list_cell(env, soa_map,
			    records_array);

			// stuff the records array in the map
			enif_make_map_put(env, map,
			    enif_make_atom(env, "records"), records_array,
			    &map);

			free(owner);
		}

		result = enif_make_tuple2(env, enif_make_atom(env, "ok"), map);
	}

	if (zone) {
		ldns_zone_free(zone);
	}
	fclose(fp);
	enif_free(zone_str);

	return result;
}

static ErlNifFunc nif_funcs[] = { { "validate", 1, validate,
				      ERL_NIF_DIRTY_JOB_CPU_BOUND },
	{ "to_map", 1, to_map, ERL_NIF_DIRTY_JOB_CPU_BOUND } };

ERL_NIF_INIT(Elixir.LDNS, nif_funcs, NULL, NULL, NULL, NULL)
