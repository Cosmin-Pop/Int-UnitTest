#!/bin/ksh
set -x # X-ray for ksh
set -e # Stop if any error
set -u # Error out if unset variable is used
 
UnitTestFile="${1}"
EMAIL_SUBJECT=''
CALLING_FUNC=''
MINOR=''
tb_Counter=0
SCRIPTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
TESTFILENAME=$(basename ${UnitTestFile})
ATTN_EMAIL_OVR=ioan-cosmin.pop-ext@socgen.com
Diffs_Exist_Send_Email='N'
Tmp_File='N'
FILE1_OkToRemove='N'
FILE2_OkToRemove='N'
# Source the library functions
. $BPT_SCRIPTS_SH/lib/library_crt.sh
# Load some needed configuration variables
. ${SCRIPTDIR}/UT.conf
TEMP_DIR=$(mktemp -d -p ${TMPDIR})
LOGFILE=$(mktemp -p ${TEMP_DIR})
export TEMP_DIR
DIFF_OUTPUT=${TEMP_DIR}/diff_output.diff
EMAIL_BODY=${TEMP_DIR}/email_body.html
 
function cleanup {
                echo Cleanup!! ${TEMP_DIR}
                # rm -rf ${TEMP_DIR}
}
 
function error {
                echo There was an error in function ${CALLING_FUNC}
                ATTN_EMAIL=${ATTN_EMAIL:-${ATTN_EMAIL_OVR}}
                ${MAILX} -s "Error in Unit Test file ${TESTFILENAME}" ${ATTN_EMAIL} < ${LOGFILE}
                exit
}
 
trap "cleanup; kill -EXIT $$" EXIT
trap "error" ERR
 
function perf_Setup_Files {
                CALLING_FUNC=${.sh.fun}
                echo "${line}"|read TEST_FILE_unchecked DEST_DIR_unchecked
                TEST_FILE=$(eval echo "${TEST_FILE_unchecked}")
                DEST_DIR=$(eval echo "${DEST_DIR_unchecked}")
                if [[ ! -d "${DEST_DIR}" ]]; then
                               echo 'ERROR : The directory ' "${DEST_DIR}" ' does not exist'
                fi
                if [[ ! -f "${TEST_FILE}" ]]; then
                               echo 'ERROR : The test file ' "${TEST_FILE}" ' does not exist'
                fi
                cp "${TEST_FILE}" "${DEST_DIR}"
}
 
function perf_SetupDB {
                CALLING_FUNC=${.sh.fun}
                SQL_COMMAND=$(eval "echo ${line}")
                echo SQL_COMMAND: ${SQL_COMMAND}
                SQL_RESULT=`executeSql "${SQL_COMMAND}"`
                echo "${SQL_RESULT[*]}"
}
 
function perf_Setup_Minor {
                CALLING_FUNC=${.sh.fun}
                case ${MINOR} in
                               11SetupFiles)
                                               perf_Setup_Files;;
                               12SetupDB)
                                               perf_SetupDB;;
                               *)
                                               set -x
                                               eval "${line}"
                                               export "${line%%=*}"
                esac
}
 
function perf_Setup {
                CALLING_FUNC=${.sh.fun}
                case ${line} in
                               11SetupFiles)
                                               MINOR=11SetupFiles;;
                               12SetupDB)
                                               MINOR=12SetupDB;;
                               *)
                                               perf_Setup_Minor;;
                esac
}
 
function perf_Run {
                CALLING_FUNC=${.sh.fun}
                set -x
                eval "${line}"
}
 
function check_unzip {
                CALLING_FUNC=${.sh.fun}
# Test the file to see if it is an archive. If it is then unzip to ${TEMP_DIR}
                file_to_check=${1}
                # TEMP_FILE=${TEMP_DIR}/$(basename ${file_to_check})
                TEMP_FILE=$(mktemp -p ${TEMP_DIR})
                set +e
                ${GZIP} -t "${file_to_check}"
                gzip_RC=$?
                set -e
                if [[ 0 -eq ${gzip_RC} ]]; then
                               ${ZCAT} ${file_to_check} > ${TEMP_FILE}
                               Tmp_File='Y'
                else
                               TEMP_FILE=${file_to_check}
                fi
}
 
function Remove_Header {
                CALLING_FUNC=${.sh.fun}
                typeset DummyFile
                typeset nb_lines
                typeset zzz
                DummyFile=$(mktemp -p ${TEMP_DIR})
                echo "${Ignore_Header}"|IFS='#' read zzz nb_lines
                nb_lines=$((nb_lines+1))
                ${TAIL} -n +${nb_lines} ${TEMP_FILE} > ${DummyFile}
                OLD_TEMP=${TEMP_FILE}
                if [[ 'Y' == ${Tmp_File} ]];then
                               rm ${OLD_TEMP}
                fi
                TEMP_FILE=${DummyFile}
                Tmp_File='Y'
}
 
function Remove_Footer {
                CALLING_FUNC=${.sh.fun}
                typeset DummyFile
                typeset nb_lines=0
                typeset zzz
                DummyFile=$(mktemp -p ${TEMP_DIR})
                echo "${Ignore_Footer}"|IFS='#' read zzz nb_lines
                ${HEAD} -n -${nb_lines} ${TEMP_FILE} > ${DummyFile}
                OLD_TEMP=${TEMP_FILE}
                if [[ 'Y' == ${Tmp_File} ]];then
                               rm ${OLD_TEMP}
                fi
                TEMP_FILE=${DummyFile}
                Tmp_File='Y'
}
 
function prep_Separator {
                CALLING_FUNC=${.sh.fun}
                unset temp_array
                IFS="," temp_array=(${ColsToCompare})
                for index in "${!temp_array[@]}"; do
                               temp_array[$index]=\$${temp_array[$index]}
                done
                ColsToCompare=$(IFS=',';echo "${temp_array[*]}")
}
 
function Select_Columns {
                CALLING_FUNC=${.sh.fun}
                set -x
                typeset DummyFile
                DummyFile=$(mktemp -p ${TEMP_DIR})
                ${AWK} -F${Field_Sep} -v OFS=${Field_Sep} "{print $ColsToCompare}" ${TEMP_FILE} > ${DummyFile}
                OLD_TEMP=${TEMP_FILE}
                if [[ 'Y' == ${Tmp_File} ]];then
                               rm ${OLD_TEMP}
                fi
                TEMP_FILE=${DummyFile}
                Tmp_File='Y'
}
 
function prep_File {
                CALLING_FUNC=${.sh.fun}
                Tmp_File='N'
                myFile=${1}
                typeset File_Name=$(basename ${myFile})
                check_unzip ${myFile}
                echo Ignore_Header: ${Ignore_Header}
                if [[ 'N' != ${Ignore_Header} ]];then
                               echo Remove_Header!!!
                               Remove_Header
                fi
                echo Ignore_Footer: ${Ignore_Footer}
                if [[ 'N' != ${Ignore_Footer} ]];then
                               echo Remove_Footer!!!
                               Remove_Footer
                fi
                echo ColsToCompare: ${ColsToCompare}
                if [[ 'ALL' != ${ColsToCompare} ]];then
                               Select_Columns
                fi
                echo Tmp_File: ${Tmp_File} ${TEMP_FILE} ${TEMP_DIR}/${File_Name}
                if [[ 'Y' == ${Tmp_File} ]];then
                               mv ${TEMP_FILE} ${TEMP_DIR}/${File_Name}
                               TEMP_FILE=${TEMP_DIR}/${File_Name}
                fi
}
 
function perf_CompareFiles {
                CALLING_FUNC=${.sh.fun}
                echo "${line}"|read Expected_File Actual_File Ignore_Header Ignore_Footer Field_Sep ColsToCompare
                Ignore_Header=${Ignore_Header:-N}
                Ignore_Footer=${Ignore_Footer:-N}
                Field_Sep=${Field_Sep:-;}
                ColsToCompare=${ColsToCompare:-ALL}
                FILE1=$(eval echo "${Expected_File}")
                # typeset Expected_File_Name=$(basename ${Expected_File})
                FILE2=$(eval echo "${Actual_File}")
                # typeset Actual_File_Name=$(basename ${Actual_File})
                prep_File ${FILE1}
                Expected_File_OkToRemove=${Tmp_File}
                Expected_File=${TEMP_FILE}
                prep_File ${FILE2}
                Actual_File_OkToRemove=${Tmp_File}
                Actual_File=${TEMP_FILE}
                diff -w -u "${Expected_File}" "${Actual_File}"
                RC_diff=$?
                if [[ 0 -eq RC_diff ]];then
                               continue
                else
                               Diffs_Exist_Send_Email='Y'
                               diff -w -u "${Expected_File}" "${Actual_File}" | ${DIFF2HTML} >> ${DIFF_OUTPUT}
                fi
                if [[ 'Y' == ${Expected_File_OkToRemove} ]];then
                               rm "${Expected_File}"
                fi
                if [[ 'Y' == ${Actual_File_OkToRemove} ]];then
                               rm "${Actual_File}"
                fi
}
 
function build_SQL {
                CALLING_FUNC=${.sh.fun}
                nb_args=$#
                echo nb_args: ${nb_args}
                echo args: $@
                case ${nb_args} in
                               3)            ## The unit test file has the table name and the fields
                                               print $@|read Expected_File Table_Name ListOfFieldsName
                                               SQL_COMMAND=$(eval "echo SELECT ${ListOfFieldsName} FROM ${Table_Name}';'")
                                               ;;
                               4)            ## The unit test file has the table name, fields and condition
                                               print $@|read Expected_File Table_Name ListOfFieldsName Condition
                                               SQL_COMMAND=$(eval "echo SELECT ${ListOfFieldsName} FROM ${Table_Name} WHERE ${Condition}';'")
                                               ;;
                               *)           ## The SQL is already built in the test case
                                               print $@|read Expected_File SQL_Statement
                                               SQL_COMMAND=$(eval "echo ${SQL_Statement}")
                                               Table_Name=$(echo ${SQL_COMMAND}|sed 's/.*From//i'|awk '{print $1}')_Given${tb_Counter}
                                               tb_Counter=$((tb_Counter+1))
                                               ;;
                esac
}
 
function perf_CompareDB {
                CALLING_FUNC=${.sh.fun}
                Table_Name=''
                SQL_COMMAND=''
                Expected_File=''
                build_SQL ${line}
                SQL_TempFile=$(mktemp -p ${TEMP_DIR})_${Table_Name}_ActualDB
                echo SQL_COMMAND: ${SQL_COMMAND}
                SQL_RESULT=`executeSql "${SQL_COMMAND}"`
                # echo "${SQL_RESULT[*]}"|tee ${SQL_TempFile}
                echo "${SQL_RESULT[*]}" > ${SQL_TempFile}
                Ignore_Header=Y#1
                TEMP_FILE=$(eval echo "${Expected_File}")
                Tmp_File='N'
                Remove_Header
                Expected_File=${TEMP_FILE}_${Table_Name}_ExpectedDB
                mv ${TEMP_FILE} ${Expected_File}
                diff -w -u "${Expected_File}" "${SQL_TempFile}"
                RC_diff=$?
                if [[ 0 -eq RC_diff ]];then
                               continue
                else
                               Diffs_Exist_Send_Email='Y'
                               diff -w -u "${Expected_File}" "${SQL_TempFile}" | ${DIFF2HTML} >> ${DIFF_OUTPUT}
                fi
}
 
function perf_Compare_Minor {
                CALLING_FUNC=${.sh.fun}
                case ${MINOR} in
                               31CompareFiles)
                                               perf_CompareFiles;;
                               32CompareDB)
                                               perf_CompareDB;;
                esac
}
 
function perf_Compare {
                CALLING_FUNC=${.sh.fun}
                case ${line} in
                               31CompareFiles)
                                               MINOR=31CompareFiles;;
                               32CompareDB)
                                               MINOR=32CompareDB;;
                               *)
                                               perf_Compare_Minor;;
                esac
}
 
function send_Email {
                CALLING_FUNC=${.sh.fun}
                echo "Subject: ${EMAIL_SUBJECT}
FROM:
To: ${line}
Content-Type: text/html; charset=us-ascii
<!doctype html public "-//w3c//dtd html 4.0 transitional//en">
" > ${EMAIL_BODY}
                cat ${DIFF_OUTPUT} >> ${EMAIL_BODY}
                ${SENDMAIL} -t < ${EMAIL_BODY}
}
 
function perf_Notify {
                CALLING_FUNC=${.sh.fun}
                set -x
# There will always be at least 21 lines if there are no differences between the actual and the expected output
# It's the default HTML code created by ${DIFF2HTML}
                if [[ ${Diffs_Exist_Send_Email} == 'Y' ]];then
                               EMAIL_SUBJECT="Unit Test FAILURE: ${TESTFILENAME}"
                else
                               EMAIL_SUBJECT="Unit Test SUCCESS: ${TESTFILENAME} was executed without error"
                fi
                send_Email
}
 
function perf_Major {
                CALLING_FUNC=${.sh.fun}
                case ${MAJOR} in
                               1Setup)
                                               perf_Setup;;
                               2Run)
                                               perf_Run;;
                               3Compare)
                                               perf_Compare;;
                               4Notify)
                                               perf_Notify;;
                esac
}
 
# Ignore comments and empty lines
grep -vE '^#|^\s*$' ${UnitTestFile}|while read -r line;
do
                case ${line} in
                               1Setup)
                                               MAJOR=1Setup;;
                               2Run)
                                               MAJOR=2Run;;
                               3Compare)
                                               MAJOR=3Compare;;
                               4Notify)
                                               MAJOR=4Notify;;
                               *)
                                               perf_Major;;
                esac
done