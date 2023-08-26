#!/usr/bin/env bash
#
# print various DNS records for a host using dig
# attempt to be thorough about all related hosts
#
# TODO: handle passing IPv4 addresses

set -o pipefail
set -eu

if [[ ${#} -ne 1 && ${#} -ne 2 ]] || [[ "${1-}" = '-h' ]]; then
    bname=$(basename -- "${0}")
    echo "Print various DNS Records for a host using dig.
Attempt to be thorough about all related hosts and IPv4 addresses.

Usage:

    ${bname} Host [DNS Server IP Address]

Example:

    ${0} www.duckduckgo.com 2>/dev/null"'
    Host  52.250.42.157       Record  42.250.52.in-addr.arpa.  IN  SOA    ns1-201.azure-dns.com. msnhst.microsoft.com. 1 900 300 604800 60
    Host  duckduckgo.com.     Record  duckduckgo.com.          IN  A      52.250.42.157
    Host  duckduckgo.com.     Record  duckduckgo.com.          IN  SOA    dns1.p05.nsone.net. hostmaster.nsone.net. 1655203370 7200 7200 1209600 14400
    Host  www.duckduckgo.com  Record  duckduckgo.com.          IN  A      52.250.42.157
    Host  www.duckduckgo.com  Record  www.duckduckgo.com.      IN  CNAME  duckduckgo.com.
'"
    ${0} www.duckduckgo.com 8.8.8.8  2>/dev/null"'
    Host  52.250.42.157       Record  42.250.52.in-addr.arpa.  IN  SOA    ns1-201.azure-dns.com. msnhst.microsoft.com. 1 900 300 604800 60
    Host  duckduckgo.com.     Record  duckduckgo.com.          IN  A      52.250.42.157
    Host  duckduckgo.com.     Record  duckduckgo.com.          IN  HINFO  "RFC8482" ""
    Host  duckduckgo.com.     Record  duckduckgo.com.          IN  SOA    dns1.p05.nsone.net. hostmaster.nsone.net. 1655203370 7200 7200 1209600 14400
    Host  www.duckduckgo.com  Record  duckduckgo.com.          IN  A      52.250.42.157
    Host  www.duckduckgo.com  Record  duckduckgo.com.          IN  SOA    dns1.p05.nsone.net. hostmaster.nsone.net. 1655203370 7200 7200 1209600 14400
    Host  www.duckduckgo.com  Record  www.duckduckgo.com.      IN  CNAME  duckduckgo.com.
'"
The dig commands are printed to stderr as they occur.
"
    exit 1
fi

host=${1}
server=${2-}
if [[ "${server}" != '' ]]; then
    server="@${server}"
fi

if ! which dig &>/dev/null; then
    echo "ERROR: dig is not found in the PATH." >&2
    echo "       On Ubuntu, try:" >&2
    echo "       sudo apt install bind9-dnsutils" >&2
    exit 1
fi

function is_IPv4 () {
    # is $1 a string that looks like and IPv4 address?
    # if yes, return 0, else return 1
    if echo -n "${1}" | grep -qEe '^([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}$'; then
        return 0
    fi
    return 1
}

function get_CNAMEs () {
    # print all CNAME records for host $1 on one line
    #
    # example function output:
    #    edgensproxy01.hippo.local. hiedgensproxy01.hippo.local.
    #
    (
    set -x 
    dig ${server} -4 -t CNAME +short +tries=1 +timeout=2 "${1}"
    ) | tr '\n' ' '
}

function get_IPv4_rev_names () {
    # print all reverse record lookup for IPv4 $1 on one line
    #
    # example dig output:
    #    172.16.178.49
    #
    # there is typically only one reverse DNS PTR Record associated with an IP Address
    # https://en.wikipedia.org/wiki/Reverse_DNS_lookup#Multiple_pointer_records
    (
    set -x
    dig ${server} \
        -4 \
        -x "${1}" \
        +answer +short +besteffort \
        +noadditional +nocomment +nocmd +noquestion +noshowsearch +nostats \
        +tries=1 +timeout=2
    ) | command -p tr '\n' ' '
}

function get_IPv4 () {
    # print the IPv4 of host $1
    #
    # example dig outputs:
    #    $ dig -4 -t A +short +tries=1 +timeout=2 "eproxy-tss22.hippo.local"
    #    edgensproxy01.hippo.local.
    #    172.16.178.191
    #
    (
        set -x
        dig ${server} \
            -4 -t A \
            +short +besteffort \
            +tries=1 +timeout=2 \
            "${1}"
    ) | command -p tail -n1
}

function host_names () {
    # fetch A Records (and possibly IP Address) for a hostname $1
    # optional $2 is type
    # print with verbose records but remove all the dig cruft
    #
    # example dig output:
    #    edgensproxy01.hippo.local. 30 IN A   172.16.178.191
    #    hippo.local.               30 IN SOA vnios01.lab.netskope.com. linto.netskope.com. 1939356 300 3600 2419200 900
    #
    (
        set -x
        dig ${server} \
            -4 -t ${2-'A'} \
            +answer +besteffort \
            +noadditional +nocomment +nocmd +noquestion +noshowsearch +nostats \
            "${1}"
    )
}
  
function host_names_rev () {
    # fetch A Records (and possibly IP Address) for a hostname $1
    # optional $2 is type
    # print with verbose records but remove all the dig cruft
    #
    # example dig output:
    #    191.178.16.172.in-addr.arpa.  3600  IN  PTR    hiedgensproxy01.hippo.local.
    #
    (
        set -x
        dig ${server} \
            -4 \
            +answer +besteffort \
            +noadditional +nocomment +nocmd +noquestion +noshowsearch +nostats \
            -x "${1}"
    )
}

# https://en.wikipedia.org/wiki/List_of_DNS_record_types
types_all=(
    A
    AAAA
    AFSDB
    APL
    CAA
    CDNSKEY
    CDS
    CERT
    CNAME
    CSYNC
    DHCID
    DLV
    DNAME
    DNSKEY
    DS
    EUI48
    EUI64
    HINFO
    HIP
    HTTPS
    IPSECKEY
    KEY
    KX
    LOC
    MX
    NAPTR
    NS
    NSEC
    NSEC3
    NSEC3PARAM
    OPENPGPKEY
    PTR
    RRSIG
    RP
    SIG
    SMIMEA
    SOA
    SRV
    SSHFP
    SVCB
    TA
    TKEY
    TLSA
    TSIG
    TXT
    URI
    ZONEMD
)
  
# pare down to relevant types
types=(
    A
    AAAA
    ANY
    CNAME
    DNAME
    PTR
)

# sometimes `column` is not available
if ! which column &>/dev/null; then
    function column () {
        command -p cat - ;
    }
fi

# preliminary information about $host
declare -a hosts=()
hosts[0]=${host}
# get IPv4 of $host
if is_IPv4 "${host}"; then
    ip=${host}
elif ! ip=$(get_IPv4 "${host}"); then
    echo "ERROR: first lookup failed" >&2
    exit 1
fi
if [[ "${ip}" = '' ]]; then
    echo "ERROR: could not determine IPv4" >&2
    exit 1
fi
# get other CNAMEs of $host
cnames=$(get_CNAMEs "${host}")
for cname in ${cnames}; do
    [[ "${cname}" != '' ]] || continue
    hosts[${#hosts[@]}]=${cname}
done

# get reverse names of IPv4
rev_names=$(get_IPv4_rev_names "${ip}")
for rname in ${rev_names}; do
    [[ "${rname}" != '' ]] || continue
    # search for previously existing name
    declare -i i=0
    declare rname_present=false
    while [[ ${i} -lt ${#hosts[@]} ]]; do
        if [[ "${hosts[${i}]}" = "${rname}" ]]; then
            rname_present=true
            break
        fi
        i+=1
    done
    if ! ${rname_present}; then
        # no matching name found, so add to list of $hosts
        hosts[${#hosts[@]}]=${rname}
    fi
done

echo "${PS4}lookup various DNS records for hosts ${hosts[*]} ${ip}" >&2
set +e

function field_ws_clean () {
    # `dig` outputs odd whitespace formatting, make it consistent ' '
    command -p tr '\r\t\v' ' ' | command -p tr -s ' '
}

readonly field_fix_sep='……'

function field_fix_in () {
    # special handler for data field $1 (a number), which may contain spaces
    # `column` does not understand some fields have spaces so this is a hacky workaround
    # call this before calling `column`
    #
    # leading counterpart to `field_fix_out`
    #
    # given a 7 field row like
    #    Host hidppool9-1.hippo.local. hippo.local. 30      IN      SOA     vnios01.lab.netskope.com. linto.netskope.com. 1939590 300 3600 2419200 900
    # replace field 7 ' ' with '…'
    declare -i fn=${1-7}
    declare -i fn_1=$((${fn} - 1))
    declare row=
    while read -r row; do
        row=$(echo -n "${row}" | command -p tr -d '\n')
        declare field_1_n=
        field_1_n=$(echo -n "${row}" | command -p cut -f "1-${fn_1}" -d ' ')
        declare field_n_=
        field_n_=$(echo -n "${row}" | command -p cut -f "${fn}-" -d ' ')
        echo "${field_1_n} ${field_n_// /${field_fix_sep}}"
    done
}

function field_fix_out () {
    # special handler for data field 7, which may contain spaces
    # call this after calling `column`
    #
    # following counterpart to `field_fix_in`
    #
    # replace all '…' with ' '
    declare row=
    while read -r row; do
        echo "${row//${field_fix_sep}/ }"
    done
}

function field_delete () {
    command -p cut -f"${1-0}" -d ' ' --complement
}

function unique_tokens () {
    # given tokens separated by spaces, treat each token as a line to be sorted,
    # reprint as tokens on a single line
    tr -s ' ' | tr ' ' '\n' | sort -u | uniq -u | tr '\n' ' '
}

{
    # query the many DNS Records for passed $host and it's CNAMEs
    for host_ in "${hosts[@]}"; do
        for type_ in "${types[@]}"; do
            if ! names=$(host_names "${host_}" "${type_}"); then
                echo "Lookup for DNS Record type ${type_} failed." >&2
                continue
            fi
            # $names is one record per-line
            while read -r record; do
                [[ "${record}" != '' ]] || continue
                echo "Host ${host_} Record ${record}"
            done <<< "$(echo -n "${names}")"
            # might trigger some network protection if these DNS queries are too fast
            sleep 0.2
        done
    done
    # also print reverse lookup of IPv4
    names=$(host_names_rev "${ip}")
    # XXX: not sure if this query ever returns more than one PTR record, but in
    #      case it does, parse as multiline
    # $names is one record per-line
    while read -r record; do
        [[ "${record}" != '' ]] || continue
        echo "Host ${ip} Record ${record}"
    done <<< "$(echo -n "${names}")"
} | field_ws_clean \
  | field_delete 5 `# delete TTL field` \
  | command -p sort -k2 -k6 \
  | command -p uniq \
  | field_fix_in 7 `# field 7 may have space but do not want column mucking with it` \
  | column -t \
  | field_fix_out \
