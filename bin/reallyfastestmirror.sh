#!/bin/bash

#set -x
#set -e

SCRIPT_PATH=`dirname "${BASH_SOURCE[0]}"`;

WGETUA="urlgrabber/3.9.1 yum/3.2.29"
LIMIT_SIZE_KIB=512

function make_dirs_global()
{
    
    for ddd in ./repofiles \
        ./repofiles/lists ./repofiles/lists/in ./repofiles/lists/out \
        ./repofiles/dirs ./repofiles/dirs/http ./repofiles/dirs/ftp ; do
        test -d ${ddd} || mkdir -v ${ddd}
    done
}

function make_dirs_per_repo()
{
    for ddd in ${dist}  ${dist}/${basearch} ; do
        test -d ./repofiles/lists/in/${ddd} || mkdir -v ./repofiles/lists/in/${ddd}
        test -d ./repofiles/lists/out/${ddd} || mkdir -v ./repofiles/lists/out/${ddd}
    done
}

function get_mirrorlist()
{
    local mirrorlist_file=./repofiles/lists/in/${dist}/${basearch}/${reponame}.mirrorlist.txt
    if [ ! -r ${mirrorlist_file} ] ; then
        echo "wget $mirrorlist"
        echo "-> ${mirrorlist_file}"
        wget --quiet --user-agent="${WGETUA}" --timeout=20 \
            --output-document ${mirrorlist_file}.0 \
            $mirrorlist    || true
        if [ -r ${mirrorlist_file}.0 ] ; then
            sed "s/\$\(basearch\|ARCH\)/"${basearch}"/g" ${mirrorlist_file}.0 > ${mirrorlist_file}
            rm -f ${mirrorlist_file}.0
        fi
    fi
    return 0
}

function make_dirs_per_mirror()
{
    for ddd in ./repofiles/dirs/${protocol} ./repofiles/dirs/${protocol}/${hostname} ./repofiles/dirs/${protocol}/${hostname}/${reponame} ; do
        test -d ${ddd} || mkdir -v ${ddd}
    done
    return 0
}

function get_check_repodata_repomd_xml()
{
    local repomd_xml_file=./repofiles/dirs/${protocol}/${hostname}/${reponame}/repomd.xml
    local repomd_result_file=./repofiles/dirs/${protocol}/${hostname}/${reponame}/repomd.result.txt
    local host_repomd_result_file=./repofiles/dirs/${protocol}/${hostname}/host.repomd.result.txt
    local repomd_xml_url=${repo_url}repodata/repomd.xml
    if [ ! -r ${repomd_xml_file} ] ; then
        echo "wget $repomd_xml_url"
        echo "-> ${repomd_xml_file}"
        wget --quiet --user-agent="${WGETUA}" --timeout=20 --tries=1 \
            --output-document ${repomd_xml_file} \
            ${repomd_xml_url} || true
    fi

    if [ -r ${repomd_xml_file} ] ; then
        echo "fm-parse-repomd-xml.pl ${repomd_xml_file}"
        echo "    > ${repomd_result_file}"
        (
            echo "repomd_xml_protocol=${protocol}"
            echo "repomd_xml_hostname=${hostname}"
            echo "repomd_xml_reponame=${reponame}"
            ${SCRIPT_PATH}/rfm-parse-repomd-xml.pl ${repomd_xml_file}
        )> ${repomd_result_file}
    fi

    if [ ! -r ${host_repomd_result_file} ] ; then
        if [ -r ${repomd_result_file} ] ; then
            cp ${repomd_result_file} ${host_repomd_result_file}
        fi
    fi
    return 0
}

function print_host_report_line()
{
    eval `cat ${1}`
    printf '%15s    %s\n' ${repomd_xml_valid_code} ${repomd_xml_protocol}://${repomd_xml_hostname}
    return 0
}

function print_host_report()
{
    export -f print_host_report_line
    find ./repofiles/dirs -type f -name host.repomd.result.txt \
        | LANG=C sort \
        | xargs -I XXX --no-run-if-empty -n 1 bash -c "print_host_report_line XXX" \
        > ./repofiles/host.report.txt
    cat ./repofiles/host.report.txt
    return 0
}

function estimate_mirror_speed()
{
    local host_speedtest_file=./repofiles/dirs/${protocol}/${hostname}/host.speedtest.txt
    local host_binary_file=./repofiles/dirs/${protocol}/${hostname}/host.speedtest.bin
    local repomd_result_file=./repofiles/dirs/${protocol}/${hostname}/${reponame}/repomd.result.txt
    if [ -r ${host_speedtest_file} ] ; then
        return 0
    fi
    if [ ! -r ${repomd_result_file} ] ; then
        return 0
    fi
    eval `cat ${repomd_result_file}`
    if [ -z "${repomd_xml_primary_db}" ] ; then
        return 0
    fi
    local primary_db_url=${repo_url}${repomd_xml_primary_db}
    host ${hostname} || true
    rm -v -f ${host_binary_file}

    echo "wget ${primary_db_url}"
    echo "-> ${host_binary_file}"
    local time1=`date --utc +%s.%N`
    (
        ulimit ${LIMIT_SIZE_KIB} ; wget --quiet --user-agent="${WGETUA}" --timeout=10 --tries=1 \
            --output-document ${host_binary_file} \
            ${primary_db_url}
    )
    local time2=`date --utc +%s.%N`
    local file_size_bytes=`du --bytes ${host_binary_file} | sed 's/[ \t].*$//'`
    local time_sec=`echo "scale=9; ${time2} - ${time1}" | bc`
    local speed_bytes_per_sec=`echo "scale=9 ; ( ${file_size_bytes} + 0 ) / ${time_sec}" | bc`

    (
        echo "mirror_protocol=${protocol}"
        echo "mirror_hostname=${hostname}"
        echo "mirror_file_size_bytes=${file_size_bytes}"
        echo "mirror_time_sec=${time_sec}"
        echo "mirror_host_speed_bytes_per_sec=${speed_bytes_per_sec}"
    )> ${host_speedtest_file}

    return 0
}

function print_speed_report_line()
{
    mirror_host_speed_bytes_per_sec=0
    eval `cat ${1}`
    if [ -z "${mirror_host_speed_bytes_per_sec}" ] ; then
        mirror_host_speed_bytes_per_sec=0
    fi

    printf '%15.3f    %s\n' ${mirror_host_speed_bytes_per_sec} ${mirror_protocol}://${mirror_hostname}
    return 0
}

function print_speed_report()
{
    local speedtest_report_file=./repofiles/speedtest.report.txt
    export -f print_speed_report_line
    find ./repofiles/dirs -type f -name host.speedtest.txt \
        | LANG=C sort \
        | xargs -I XXX --no-run-if-empty -n 1 bash -c "print_speed_report_line XXX" \
        | LANG=C sort -r -n > ${speedtest_report_file}
    head -n 50 ${speedtest_report_file}
    return 0
}

function write_new_mirrorlist()
{
    local speedtest_report_file=./repofiles/speedtest.report.txt
    local mirrorlist_file=./repofiles/lists/in/${dist}/${basearch}/${reponame}.mirrorlist.txt
    local mirrorlist_out_file=./repofiles/lists/out/${dist}/${basearch}/${reponame}.mirrorlist.txt
    if [ ! -r ${mirrorlist_file} ] ; then
        return 0
    fi
    echo "rfm-sort-mirrorlist.pl ${speedtest_report_file} ${mirrorlist_file}"
    echo "    > ${mirrorlist_out_file}"
    ${SCRIPT_PATH}/rfm-sort-mirrorlist.pl ${speedtest_report_file} ${mirrorlist_file} > ${mirrorlist_out_file}
    return 0
}


function loop_over_repos_arches()
{
    local callback_name=${1}
    if [ -z "${callback_name}" ] ; then
        return 250
    fi
    for repoconf in ./conf/repos/*.conf ; do
        if [ ! -f "${repoconf}" ] ; then
            continue
        fi
        for archconf in ./conf/arches/*.conf ; do
            if [ ! -f "${archconf}" ] ; then
                continue
            fi
            eval `cat ${archconf} ${repoconf}`
            ${callback_name}
        done
    done
    return 0
}

function loop_over_repos_arches_mirrors()
{
    local callback_name=${1}
    if [ -z "${callback_name}" ] ; then
        return 250
    fi
    for repoconf in ./conf/repos/*.conf ; do
        if [ ! -f "${repoconf}" ] ; then
            continue
        fi
        for archconf in ./conf/arches/*.conf ; do
            if [ ! -f "${archconf}" ] ; then
                continue
            fi
            eval `cat ${archconf} ${repoconf}`
            local mirrorlist_file=./repofiles/lists/in/${dist}/${basearch}/${reponame}.mirrorlist.txt
            if [ ! -r ${mirrorlist_file} ] ; then
                continue
            fi
            while read -r line ; do
                if [[ ! ( $line =~ ^(http|ftp): ) ]] ; then
                    continue
                fi
                local url0=$line
                eval `${SCRIPT_PATH}/rfm-parse-url.pl ${url0}`
                protocol=${parse_protocol}
                hostname=${parse_host}
                repo_url=${parse_url}
                if [ -z "${protocol}" ] ; then
                    continue
                fi
                ${callback_name}
            done < "${mirrorlist_file}"
        done
    done
    return 0
}

function do_main()
{
local line=
make_dirs_global

echo "Creating per-repository directories"

loop_over_repos_arches     make_dirs_per_repo

echo "Getting mirror lists"

loop_over_repos_arches     get_mirrorlist

echo "Creating per-mirror directories"

loop_over_repos_arches_mirrors    make_dirs_per_mirror

echo "Getting and checking per-mirror repodata/repomd.xml"

loop_over_repos_arches_mirrors    get_check_repodata_repomd_xml

print_host_report

echo "Estimating per-host speed"

loop_over_repos_arches_mirrors    estimate_mirror_speed

print_speed_report

loop_over_repos_arches     write_new_mirrorlist

return 0
}

do_main "${@}"
