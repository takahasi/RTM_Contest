#!/bin/bash
# @(#) This is metrics checker script for RTM contest 2016.

# Checks unnecessary paramters
set -u

####################
# GLOBAL CONSTANTS #
####################
# readonly XXX="xxx"
readonly num_of_entry=10
readonly required_packages=(git wget sloccount cppcheck egrep pyflakes flake8 findbugs cloc cpplint.py)

####################
# GLOBAL VARIABLES #
####################
# XXX="xxx"

## Usage
function usage() {
  cat <<EOF
  Usage:
    ./`basename $0`

  Description:
    This is metrics checker script for RTM contest 2016.

  Options:
    -h, --help       : Print usage

  Note:
    This script needs following packages
    `echo "- ${required_packages[@]}"`

EOF
  return 0
}

# cleanup & create empty folfer
function cleanup_project()
{
  rm -rf $1
  mkdir -p $1/src $1/doc $1/util

  return 0
}

# check necessary commands
function check_commands()
{
  for p in "${required_packages[@]}"
  do
    if [ "${p}" == "cpplint.py" ]; then
      test "${p}" > /dev/null 2>&1
    else
      type "${p}" > /dev/null 2>&1
    fi
    if [ ! $? == 0 ]; then
      echo "check ${p}: not exist"
      if [ "${p}" == "cpplint.py" ]; then
        wget https://raw.githubusercontent.com/google/styleguide/gh-pages/cpplint/cpplint.py
      else
        sudo apt-get install ${p}
      fi
    else
      echo "check ${p}: ok"
    fi
  done

  return 0
}

# get project title from HTML of project page
function get_project_title()
{
  if [ -d $1 ]; then
    local base_url=http://www.openrtm.org/openrtm/ja/project/contest2017
    echo ${base_url}_$1 > $1/url.txt
    wget ${base_url}_$1 -O - | egrep "<title>.*</title>" | sed -e "s/<[^>]*>//g" -e "s/ //g" -e "s/|.*//g" | tr -d '\t'> $1/title.txt
  fi

  return 0
}

# get number of RTC by counting keyword of source code
function get_project_rtcs()
{
  if [ -d $1 ]; then
    find $1 \( -name "*.py" -o -name "*.cpp" -o -name "*.java" -o -name "*.cs" \) -print0 | xargs -0 grep -l -i "CreateComponent" | sed 's/.*\///' > $1/rtc.txt
  fi

  return $?
}

# get project licence
function get_project_licenses()
{
  if [ -d $1 ]; then
    egrep License $1 -r -l | sed -e 's/[0-9]*$//g' | egrep -v "cpack_resources|cmake\/License.rtf|.*\.in" | uniq
  fi

  return 0
}

# count step of whole source code
function count_source_code_all()
{
  if [ -d $1 ]; then
    sloccount --duplicates --wide $1 > $1/sloccount_all.txt
    egrep "%" $1/sloccount_all.txt | tr -d ' '
  fi

  return 0
}

# count step of RTC source code
function count_source_code_cloc()
{
  if [ -d $1 ]; then
    cloc --quiet --csv $1/src/ | sed -e '1d' -e 's/,"http.*//g' > $1/sloccount_cloc.csv
    csv2md $1/sloccount_cloc.csv
  fi

  return 0
}

function count_source_code_comment_rate()
{
  local comment=`cloc --quiet --xml $1/src/ | sed -e '1d'| xmllint --xpath "//results/languages/total/@comment" -| sed 's/[^"]*"\([^"]*\)"[^"]*/\1/g'`
  local code=`cloc --quiet --xml $1/src/ | sed -e '1d'| xmllint --xpath "//results/languages/total/@code" -| sed 's/[^"]*"\([^"]*\)"[^"]*/\1/g'`

  echo "scale=2; $comment / $code * 100" | bc
}

function count_source_code_warning_rate()
{
  local code=`cloc --quiet --xml $1/src/ | sed -e '1d'| xmllint --xpath "//results/languages/total/@code" -| sed 's/[^"]*"\([^"]*\)"[^"]*/\1/g'`
  local warning=`cat $1/warnings.txt | wc -l`

  echo "scale=2; $warning / $code * 100" | bc
}


# search project executables
function get_project_executables()
{
  if [ -d $1 ]; then
    find $1 -type f -not -name "*.txt" -print | xargs file | grep "executable" | egrep -v "DLL|Python|shell script" | sed 's/.*\/\(.*:\)/\1/g' | sed -e 's/ //g'
  fi

  return 0
}


# analyze project
function analyse_project()
{
  if [ ! -d $1 ]; then
      return 1
  fi

  get_project_title $1

  # create empty files for output
  touch $1/errors.txt
  touch $1/warnings.txt
  touch $1/rtc.txt
  touch $1/stepcount_all.txt
  touch $1/stepcount_cloc.txt
  touch $1/stepcount_comment_rate.txt
  touch $1/stepcount_warning_rate.txt
  touch $1/licenses.txt
  touch $1/executables.txt

  if [ ! -z "$(ls -A $1/src)" ]; then
    get_project_rtcs $1

    # step count
    count_source_code_all $1 > $1/stepcount_all.txt
    count_source_code_cloc $1 > $1/stepcount_cloc.txt
    count_source_code_comment_rate $1 > $1/stepcount_comment_rate.txt

    # static analysis for C/C++
    find $1/src \( -name "*.c" -o -name "*.cpp" \) -print | egrep -v "idl" > $1/filelist_cpp.txt
    if [ -s $1/filelist_cpp.txt ]; then
      cat $1/filelist_cpp.txt | sed 's/ /" "/g' | xargs cppcheck --enable=all 2> $1/cppcheck.txt
      cat $1/filelist_cpp.txt | sed 's/ /" "/g' | xargs python cpplint.py 2> $1/cpplint.txt
    else
      touch $1/cppcheck.txt
      touch $1/cpplint.txt
    fi

    # static analysis for Python
    find $1/src \( -name "*.py" \) -print0 > $1/filelist_python.txt
    if [ -s $1/filelist_python.txt ]; then
      # cat $1/filelist_python.txt | xargs -0 pyflakes > $1/pyflakes.txt
      cat $1/filelist_python.txt | xargs -0 flake8 > $1/pyflakes.txt
    else
      touch $1/pyflakes.txt
    fi

    # static analysis for Java
    find $1/src \( -name "*.java" \) -print0 > $1/filelist_java.txt
    if [ -s $1/filelist_java.txt ]; then
      findbugs -textui -quiet -emacs $1/src > $1/findbugs.txt
    else
      touch $1/findbugs.txt
    fi

    # collects errors
    {
      egrep "error" $1/cppcheck.txt
      cat $1/findbugs.txt | egrep -v -e '^\s*$' | egrep "\(H\)"
    } > $1/errors.txt

    # collects warnings
    {
      egrep -v "information|error" $1/cppcheck.txt
      cat $1/cpplint.txt
      cat $1/pyflakes.txt | egrep -v -e '^\s*$'
      cat $1/findbugs.txt | egrep -v -e '^\s*$' | egrep -v "\(H\)"
    } > $1/warnings.txt

    get_project_licenses $1 > $1/licenses.txt
    get_project_executables $1 > $1/executables.txt
    count_source_code_warning_rate $1 > $1/stepcount_warning_rate.txt
  fi

  generate_project_summary $1 > $1/summary.txt
  generate_project_report $1 > $1/report.txt

  return 0
}

# generate project summary header
function generate_project_summary_header()
{
  cat << EOS
<a name="summary">

SUMMARY
=======

|No|Title|RTCs|LOC|COM%|WARN%|ERRs|WARNs|Licences|EXEs|
|--|-----|----|---|----|-----|----|-----|--------|----|
EOS

  return 0
}

# generate project summary
function generate_project_summary()
{
  cat << EOS
|[$1](#$1)|[`cat $1/title.txt`](`cat $1/url.txt`)|`cat $1/rtc.txt | wc -l`|`cat $1/stepcount_all.txt | tr '\n' '/' | sed -e "s/\//<br>/g"`|`cat $1/stepcount_comment_rate.txt`%|`cat $1/stepcount_warning_rate.txt`%|`cat $1/errors.txt | wc -l`|`cat $1/warnings.txt | wc -l`|`cat $1/licenses.txt | wc -l`|`cat $1/executables.txt | wc -l`|
EOS

  return 0
}

# generate project report
function generate_project_report()
{
  cat << EOS
<a name="$1">

Entry No.  : $1
===============

Title
-----
`cat $1/title.txt | sed 's/|.*//' | tr -d '\t'`

URL
---
<`cat $1/url.txt`>

RTCs
----
`cat $1/rtc.txt | wc -l` components

`cat $1/rtc.txt | sed 's/^/* /'`

Line of Code
------------

### Total

`cat $1/stepcount_all.txt | sed 's/^/* /'`

### Comment Rate

`cat $1/stepcount_comment_rate.txt` %

### Detail

`cat $1/stepcount_cloc.txt`

Errors
------
`cat $1/errors.txt | wc -l` errors

\`\`\`
`cat $1/errors.txt | sed 's/^/* /'`
\`\`\`

Warnings
--------
`cat $1/warnings.txt | wc -l` warnings

\`\`\`
`cat $1/warnings.txt | sed 's/^/* /'`
\`\`\`

Licenses
--------
`cat $1/licenses.txt | wc -l` licenses

\`\`\`
`cat $1/licenses.txt | sed 's/^/* /'`
\`\`\`

Executables
-----------
`cat $1/executables.txt | wc -l` executables

* win32
`cat $1/executables.txt | egrep -i "windows" | egrep -i "386" | sed 's/^/  * /'`
* win64
`cat $1/executables.txt | egrep -i "windows" | egrep -i "x86-64" | sed 's/^/  * /'`
* linux32
`cat $1/executables.txt | egrep -i "linux" | egrep -i "32-bit" | sed 's/^/  * /'`
* linux64
`cat $1/executables.txt | egrep -i "linux" | egrep -i "64-bit" | sed 's/^/  * /'`

[Back to summary](#summary)

---

EOS

  return 0
}

# wrapper of git clone
function _git_clone()
{
  # shallow clone
  git clone --depth 1 $1 $2/`basename $1`
  rm -rf $2/`basename $1`/.git

  return $?
}

# wrapper of wget
function _wget()
{
  wget $1 -P $2/

  return $?
}


function get_project_01()
{
  local project=01
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/MasutaniLab/robot-programming-manager $project_src

  # get document
  cp $project_src/robot-programming-manager/RPMspecification.md $project_doc
  cp $project_src/robot-programming-manager/config.md $project_doc
  cp $project_src/robot-programming-manager/sample1.md $project_doc
  cp $project_src/robot-programming-manager/sample2.md $project_doc

  # get utility tools

  return 0
}

function get_project_02()
{
  local project=02
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _wget http://www.sic.shibaura-it.ac.jp/~md17067/RTMC2017/PhotographyRobot2017.zip $project_src
  (cd $project_src && unzip PhotographyRobot2017.zip)
  _wget http://www.sic.shibaura-it.ac.jp/~md17067/RTMC2017/bat_file.zip $project_src
  (cd $project_src && unzip bat_file.zip)

  # get documents
  http://www.sic.shibaura-it.ac.jp/~md17067/RTMC2017/contest2017_02_summary.pdf

  # get utility tools

  return 0
}

function get_project_03()
{
  local project=03
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/rsdlab/py_faster_rcnnRTC $project_src
  _git_clone https://github.com/rsdlab/WebCamera $project_src
  _git_clone https://github.com/rsdlab/ImageViewer $project_src
  _git_clone https://github.com/rsdlab/Show_ObjectParam $project_src

  # get documents
  _wget https://github.com/rsdlab/py_faster_rcnnRTC/blob/master/%E6%B7%B1%E5%B1%A4%E5%AD%A6%E7%BF%92%E3%82%92%E7%94%A8%E3%81%84%E3%81%9F%E7%89%A9%E4%BD%93%E8%AA%8D%E8%AD%98%E3%82%B3%E3%83%B3%E3%83%9B%E3%82%9A%E3%83%BC%E3%83%8D%E3%83%B3%E3%83%88%E7%BE%A4.pdf $project_doc

  # get utility tools

  return 0
}

function get_project_04()
{
  local project=04
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/rsdlab/AVSdeviceSDKWrapperRTC.git $project_src

  # get documents
  _wget https://github.com/rsdlab/AVSdeviceSDKWrapperRTC/blob/master/AVSdeviceSDKWrapper%20RTC.pdf $project_doc

  # get utility tools

  return 0
}

function get_project_05()
{
  local project=05
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _wget http://www.sic.shibaura-it.ac.jp/~ab13076/RTMC2017/contest2017_05.html/Data_Transfer.zip $project_src
  (cd $project_src && unzip Data_Transfer.zip)

  # get documents
  _wget www.sic.shibaura-it.ac.jp/~ab13076/contest2017_gaiyou.pdf $project_doc

  # get utility tools

  return 0
}

function get_project_06()
{
  local project=06
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/Nobu19800/OpenRTMPythonPlugin $project_src

  # get documents
  _wget https://github.com/Nobu19800/OpenRTMPythonPlugin/wiki $project_doc

  # get utility tools

  return 0
}

function get_project_07()
{
  local project=07
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _wget http://www.sic.shibaura-it.ac.jp/~ab14105/RTMC2017/RTC_iWs09.zip $project_src
  (cd $project_src && unzip RTC_iWs09.zip)

  # get documents
  _wget http://www.sic.shibaura-it.ac.jp/~ab14105/RTMC2017/contest_07_manual.pdf $project_doc

  # get utility tools

  return 0
}

function get_project_08()
{
  local project=08
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/Konan-Robot-Koubou/SI2017 $project_src

  # get documents
  _wget http://openrtm.org/openrtm/sites/default/files/Slide_contest2017_08.pdf $project_doc
  _wget https://github.com/Konan-Robot-Koubou/SI2017/blob/master/Manual_SI2017_Zumo.pdf $project_doc
  _wget https://github.com/Konan-Robot-Koubou/SI2017/blob/master/Manual_SI2017_pi2go.pdf $project_doc

  # get utility tools

  return 0
}

function get_project_09()
{
  local project=09
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/rokihi/MobileRobotShootingGameRTC $project_src
  _git_clone https://github.com/rokihi/ARTKMarkerInfoToPose2D $project_src

  # get documents

  # get utility tools

  return 0
}

function get_project_10()
{
  local project=10
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/takahasi/docker-openrtm $project_src
  _git_clone https://github.com/takahasi/docker-openrtm-tools $project_src

  # get documents


  # get utility tools

  return 0
}


################
# MAIN ROUTINE #
################

while (( $# > 0 ))
do
  case "$1" in
    '-h'|'--help' )
      usage
      exit 1
      ;;
    *)
      #echo "[ERROR] invalid option $1 !!"
      #usage
      #exit 1
      ;;
  esac
  shift
done

check_commands

for i in `seq -w $num_of_entry`
do
  echo ""
  echo "--> Start PROJECT_$i"
  echo ""
  cleanup_project $i
  get_project_$i
  analyse_project $i
done

report="report_`date +%Y%m%d`.md"
generate_project_summary_header > $report
cat */summary.txt >> $report
echo "" >> $report
cat */report.txt >> $report

echo ""
echo "Completed $i projects"
echo ""

exit 0

