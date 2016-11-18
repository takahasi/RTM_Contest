#!/bin/bash
# @(#) This is metrics checker script for RTM contest 2016.

# Checks unnecessary paramters
set -u

####################
# GLOBAL CONSTANTS #
####################
# readonly XXX="xxx"
readonly num_of_entry=13
readonly required_packages=(git wget sloccount cppcheck egrep pyflakes findbugs)

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
    if [ ! type "${p}" > /dev/null 2>&1 ]; then
      echo "please install ${p} !"
      echo "---"
      usage
      exit 1
    fi
  done

  return 0
}

# get project title from HTML of project page
function get_project_title()
{
  if [ -d $1 ]; then
    local base_url=http://www.openrtm.org/openrtm/ja/project/contest2016
    echo ${base_url}_$1 > $1/url.txt
    wget ${base_url}_$1 -O - | egrep "<title>.*</title>" | sed -e "s/<[^>]*>//g" | sed -e "s/ //g" > $1/title.txt
  fi

  return 0
}

# get number of RTC by counting keyword of source code
function get_project_rtcs()
{
  if [ -d $1 ]; then
    find $1 \( -name "*.py" -o -name "*.cpp" -o -name "*.java" \) -print0 | xargs -0 grep -l -i "MyModuleInit(" | sed 's/.*\///' > $1/rtc.txt
  fi

  return $?
}

# get project licence
function get_project_licenses()
{
  if [ -d $1 ]; then
    egrep License $1 -r -l | sed -e 's/[0-9]*$//g' | egrep -v "cpack_resources|cmake\/License.rtf|.*\.in" | uniq | sed 's/.*\///g'
  fi

  return 0
}

# count step of whole source code
function count_source_code_all()
{
  if [ -d $1 ]; then
    sloccount --duplicates --wide $1 > $1/sloccount_all.txt
    egrep "%" $1/sloccount_all.txt
  fi

  return 0
}

# count step of RTC source code
function count_source_code_rtcs()
{
  if [ -d $1 ]; then
    sloccount --duplicates --wide $1/src > $1/sloccount_rtc.txt
    egrep -v "%" $1/sloccount_rtc.txt | egrep "cpp=|java=|python=|xml=|sh=|%"
  fi

  return 0
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
  touch $1/stepcount_rtc.txt
  touch $1/licenses.txt
  touch $1/executables.txt

  if [ ! -z "$(ls -A $1/src)" ]; then
    get_project_rtcs $1

    # step count
    count_source_code_all $1 > $1/stepcount_all.txt
    count_source_code_rtcs $1 > $1/stepcount_rtc.txt

    # static analysis for C/C++
    find $1/src \( -name "*.c" -o -name "*.cpp" \) -print0 > $1/filelist_cpp.txt
    if [ -s $1/filelist_cpp.txt ]; then
      cppcheck --enable=all $1/src 2> $1/cppcheck.txt
    else
      touch $1/cppcheck.txt
    fi

    # static analysis for Python
    find $1/src \( -name "*.py" \) -print0 > $1/filelist_python.txt
    if [ -s $1/filelist_python.txt ]; then
      cat $1/filelist_python.txt | xargs -0 pyflakes > $1/pyflakes.txt
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
      cat $1/pyflakes.txt | egrep -v -e '^\s*$'
      cat $1/findbugs.txt | egrep -v -e '^\s*$' | egrep -v "\(H\)"
    } > $1/warnings.txt

    get_project_licenses $1 > $1/licenses.txt
    get_project_executables $1 > $1/executables.txt
  fi

  generate_project_summary $1 > $1/summary.txt
  generate_project_report $1 > $1/report.txt

  return 0
}

# generate project summary
function generate_project_summary()
{
  cat << EOS
-----------------------------
Entry No.  : $1/
Title      : `cat $1/title.txt`
URL        : `cat $1/url.txt`
RTCs       : `cat $1/rtc.txt | wc -l`
`cat $1/rtc.txt | sed 's/^/  - /'`

Step(all)  :
`cat $1/stepcount_all.txt | sed 's/^/  - /'`

Step(RTC)  :
`cat $1/stepcount_rtc.txt | sed 's/^/  - /'`

Errors     : `cat $1/errors.txt | wc -l`
`cat $1/errors.txt | sed 's/^/  - /'`

Warnings   : `cat $1/warnings.txt | wc -l`
  please check $1/warnings.txt

Licenses   : `cat $1/licenses.txt | wc -l`
  please check $1/licenses.txt

Executables: `cat $1/executables.txt | wc -l`
  [win32]
`cat $1/executables.txt | egrep -i "windows" | egrep -i "386" | cut -d: -f1 | sed 's/^/  - /'`
  [win64]
`cat $1/executables.txt | egrep -i "windows" | egrep -i "x86-64" | cut -d: -f1 | sed 's/^/  - /'`
  [linux32]
`cat $1/executables.txt | egrep -i "linux" | egrep -i "32-bit" | cut -d: -f1 | sed 's/^/  - /'`
  [linux64]
`cat $1/executables.txt | egrep -i "linux" | egrep -i "64-bit" | cut -d: -f1 | sed 's/^/  - /'`

-----------------------------
EOS

  return 0
}

# generate project report
function generate_project_report()
{
  cat << EOS
-----------------------------
Entry No.  : $1/
Title      : `cat $1/title.txt`
URL        : `cat $1/url.txt`
RTCs       : `cat $1/rtc.txt | wc -l`
`cat $1/rtc.txt | sed 's/^/  - /'`

Step(all)  :
`cat $1/stepcount_all.txt | sed 's/^/  - /'`

Step(RTC)  :
`cat $1/stepcount_rtc.txt | sed 's/^/  - /'`

Errors     : `cat $1/errors.txt | wc -l`
`cat $1/errors.txt | sed 's/^/  - /'`

Warnings   : `cat $1/warnings.txt | wc -l`
`cat $1/warnings.txt | sed 's/^/  - /'`

Licenses   : `cat $1/licenses.txt | wc -l`
`cat $1/licenses.txt | sed 's/^/  - /'`

Executables: `cat $1/executables.txt | wc -l`
  [win32]
`cat $1/executables.txt | egrep -i "windows" | egrep -i "386" | sed 's/^/  - /'`
  [win64]
`cat $1/executables.txt | egrep -i "windows" | egrep -i "x86-64" | sed 's/^/  - /'`
  [linux32]
`cat $1/executables.txt | egrep -i "linux" | egrep -i "32-bit" | sed 's/^/  - /'`
  [linux64]
`cat $1/executables.txt | egrep -i "linux" | egrep -i "64-bit" | sed 's/^/  - /'`

-----------------------------
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
  _git_clone https://github.com/Nobu19800/Crawl_Gait_Controller $project_src
  _git_clone https://github.com/Nobu19800/Intermittent_Crawl_Gait_Controller $project_src
  _git_clone https://github.com/Nobu19800/Foot_Position_Controller $project_src
  _git_clone https://github.com/Nobu19800/Four_legged_Robot_Simulator $project_src
  _git_clone https://github.com/Nobu19800/FourLeggedRobot_RTno $project_src
  _git_clone https://github.com/Nobu19800/EV3_Leg_Controller $project_src
  _git_clone https://github.com/Nobu19800/Four_legged_Robot_Scripts $project_src

  # get document
  _wget http://www.openrtm.org/openrtm/sites/default/files/6110/rtmcontest2016_01.pdf $project_doc

  # get utility tools
  _git_clone https://github.com/Nobu19800/Four_legged_Robot_Scripts $project_util

  return 0
}

function get_project_02()
{
  local project=02
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/Nobu19800/RaspberryPiMouseController_DistanceSensor $project_src
  _git_clone https://github.com/Nobu19800/RaspberryPiMouseGUI $project_src
  _git_clone https://github.com/Nobu19800/NineAxisSensor_RT_USB $project_src
  _git_clone https://github.com/Nobu19800/RaspberryPiMouseController_Joystick $project_src
  _git_clone https://github.com/Nobu19800/RasPiMouseSample $project_src
  _git_clone https://github.com/Nobu19800/EV3Sample $project_src
  _git_clone https://github.com/Nobu19800/EducatorVehicle $project_src
  _git_clone https://github.com/Nobu19800/ControlEducatorVehicle $project_src
  _git_clone https://github.com/Nobu19800/TetrixVehicle  $project_src
  _git_clone https://github.com/Nobu19800/VehicleController $project_src
  _git_clone https://github.com/Nobu19800/FloatSeqToVelocity $project_src

  # get documents
  _wget http://www.openrtm.org/openrtm/sites/default/files/6111/rtmcontest2016_02.pdf $project_doc

  # get utility tools
  _git_clone https://github.com/Nobu19800/RaspberryPiMouseRTSystem_script $project_util
  _git_clone https://github.com/Nobu19800/RaspberryPiMouseRTSystem_script_Raspbian $project_util
  _git_clone https://github.com/Nobu19800/CalibrationUSBNineAxisSensor $project_util
  _git_clone https://github.com/Nobu19800/EducatorVehicle_script $project_util
  _git_clone https://github.com/Nobu19800/EducatorVehicle_script_ev3dev $project_util
  _git_clone https://github.com/Nobu19800/saveBinaryImage $project_util

  return 0
}

function get_project_03()
{
  local project=03
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/sako35/SoundDirectionRTC2 $project_src
  mv $project_src/SoundDirectionRTC2/* $project_src/

  # get documents
  mv $project_src/*.pdf $project_doc/

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
  _git_clone https://github.com/Sakakibara-Hiroyuki/openRTM2016_04 $project_src
  mv $project_src/openRTM2016_04/* $project_src/

  # get documents
  mv $project_src/*.pdf $project_doc/

  # get utility tools

  return 1
}

function get_project_05()
{
  local project=05
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/MatsudaR/RaspberryPi-Arduino-Duo-RTC $project_src
  mv $project_src/RaspberryPi-Arduino-Duo-RTC/* $project_src/

  # get documents
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
  _wget http://www.sic.shibaura-it.ac.jp/~md16005/Ikeda/rtc/utteranceServer.zip $project_src
  unzip $project_src/utteranceServer.zip -d $project_src/
  _wget http://www.sic.shibaura-it.ac.jp/~md16005/Ikeda/rtc/ConciregeRSNP5.zip $project_src
  unzip $project_src/ConciregeRSNP5.zip -d $project_src/

  # get documents
  _wget http://www.sic.shibaura-it.ac.jp/~md16005/Ikeda/contest2016_06summary.pdf $project_doc
  _wget http://www.sic.shibaura-it.ac.jp/~md16005/Ikeda/contest2016_06manual.pdf $project_doc

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
  _git_clone https://github.com/rsdlab/CRANE-simulation $project_src
  mv $project_src/CRANE-simulation/* $project_src/

  # get documents
  mv $project_src/*.pdf $project_doc/

  # get utility tools
  mv $project_src/model_project $project_util/
  mv $project_src/script $project_util/

  return 0
}

function get_project_08()
{
  local project=08
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  # get documents
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
  # get documents
  # get utility tools

  return 0
}

function get_project_11()
{
  local project=11
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _wget http://www.sic.shibaura-it.ac.jp/~md16042/Shimoyama2016/rtc/Attention_degree.zip $project_src
  unzip $project_src/Attention_degree.zip -d $project_src/

  # get documents
  _wget http://www.sic.shibaura-it.ac.jp/~md16042/Shimoyama2016/contest2016_gaiyou.pdf $project_doc
  _wget http://www.sic.shibaura-it.ac.jp/~md16042/Shimoyama2016/contest2016_manual.pdf $project_doc

  # get utility tools

  return 0
}

function get_project_12()
{
  local project=12
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _wget http://www.openrtm.org/openrtm/sites/default/files/6133/StarTno_2016_V2.zip $project_src/
  unzip $project_src/StarTno_2016_V2.zip -d $project_src/
  mv $project_src/StarTno_2016_V2/* $project_src/
  mv $project_src/00_StarTno_00_Win7_VsualStudio2013/* $project_src/

  # get documents
  _wget http://www.openrtm.org/openrtm/sites/default/files/6133/M_%E3%83%9E%E3%83%8B%E3%83%A5%E3%82%A2%E3%83%AB_%E3%81%BE%E3%81%A8%E3%82%81.zip $project_doc/
  unzip $project_doc/M_*.zip -d $project_doc/
  find  $project_src \( -name "*.pdf" -o -name "*.doc*" \) -print0 | xargs -0 -i mv {} $project_doc/

  # get utility tools
  mv $project_src/00_*RTno* $project_util/

  return 0
}

function get_project_13()
{
  local project=13
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/mediart-C/Magicalight $project_src
  mv $project_src/Magicalight/* $project_src/

  # get documents
  mv $project_src/*.pdf $project_doc/

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

cat */summary.txt > summary_`date +%Y%m%d`.txt
cat */report.txt > report_`date +%Y%m%d`.txt

echo ""
echo "Completed $i projects"
echo ""

exit 0

