#!/usr/bin/env bash

set -e

export SMB_HOSTS_ALLOW=${SMB_HOSTS_ALLOW:-''}
export SMB_HOSTS_DENY=${SMB_HOSTS_DENY:-'ALL'}

export LDAP_URL=${LDAP_URL:-''}
export LDAP_SEARCH_BASE=${LDAP_SEARCH_BASE:-''}
export LDAP_USER_SEARCH_BASE=${LDAP_USER_SEARCH_BASE:-''}
export LDAP_GROUP_SEARCH_BASE=${LDAP_GROUP_SEARCH_BASE:-''}

find /docker-entrypoint.d/ -type f | while read filename; do
  # out_dir is the filename without the leading /docker-entrypoint.d/
  # e.g. /docker-entrypoint.d/smb.conf.template -> smb.conf.template
  out_dir="/$(dirname ${filename#/docker-entrypoint.d/})"
  out_file=$(basename "${filename}")

  mkdir -p "${out_dir}"

  if [[ "$filename" == *.template ]]; then
    out_file="${out_file%.template}"
    echo "Processing template ${filename} to ${out_file}"
    envsubst < "${filename}" > "${out_dir}/${out_file}"
  else
    echo "Copying file ${filename} to ${out_dir}/${out_file}"
    cp "${filename}" "${out_dir}/${out_file}"
  fi

  # force the sssd.conf permissions to 600
  if [[ "${out_file}" == "sssd.conf" ]]; then
    chmod 600 "${out_dir}/${out_file}"
  fi
done

test -d /etc/samba/conf.d && find /etc/samba/conf.d -type f | sort | while read filename; do
  echo "Including additional samba config file: ${filename}"
  echo "  include = ${filename}" >> /etc/samba/smb.conf
done

exec "$@"
