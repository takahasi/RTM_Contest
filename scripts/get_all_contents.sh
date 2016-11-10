#!/bin/bash
# @(#) This is metrics checker script for RTM contest 2016.

# Checks unnecessary paramters
set -u

####################
# GLOBAL CONSTANTS #
####################
# readonly XXX="xxx"
readonly num_of_entry=13

####################
# GLOBAL VARIABLES #
####################
# XXX="xxx"

## Usage
function usage() {
  cat <<EOF
  Usage:
    $0
  Description:
    This is metrics checker script for RTM contest 2016.
  Options:
    -h, --help       : Print usage
  Note:
    This script needs following packages
      - git
      - wget
      - sloccount
      - cppcheck
EOF
  return 1
}

# cleanup
function cleanup_project()
{
  rm -rf $1
  mkdir -p $1/src $1/doc $1/util
}

function check_commands()
{
  if ! type git > /dev/null 2>&1; then
    echo "please install git !"
    exit 1
  elif ! type wget > /dev/null 2>&1; then
    echo "please install wget !"
    exit 1
  elif ! type sloccount > /dev/null 2>&1; then
    echo "please install sloccount !"
    exit 1
  elif ! type cppcheck > /dev/null 2>&1; then
    echo "please install cppcheck !"
    exit 1
  fi
}

function get_project_title()
{
  local base_url=http://www.openrtm.org/openrtm/ja/project/contest2016
  echo ${base_url}_$1 > $1/url.txt
  wget ${base_url}_$1 -O - | egrep "<title>.*</title>" | sed -e "s/<[^>]*>//g" | sed -e "s/ //g" > $1/title.txt
}

function get_project_rtc_number()
{
  find $1 -name "*.py" -o -name "*.cpp" -o -name "*.java" | xargs grep -i "MyModuleInit(" | wc -l > $1/rtc_num.txt
}

function generate_project_summary()
{
  cat << EOS
-----------------------------
Entry No.  : $1/
Title      : `cat $1/title.txt`
URL        : `cat $1/url.txt`
# of RTC   : `cat $1/rtc_num.txt`
Step(all)  :
`cat $1/stepcount_all.txt`

Step(RTC)  :
`cat $1/stepcount_rtc.txt`

Errors     :
`cat $1/errors.txt`

-----------------------------
EOS
}

function analyse_project()
{
  get_project_title $1

  if [ ! -z "$(ls -A $1/src)" ]
  then
    get_project_rtc_number $1

    sloccount --duplicates --wide $1 > $1/sloccount.txt
    egrep "%" $1/sloccount.txt > $1/stepcount_all.txt
    egrep -v "%" $1/sloccount.txt | egrep "cpp|java|python|xml|sh|%" > $1/stepcount_rtc.txt

    cppcheck --enable=all $1/src 2> $1/cppcheck.txt
    egrep "error" $1/cppcheck.txt > $1/errors.txt
  fi

  generate_project_summary $1 > $1/summary.txt
}

# wrapper of git clone
function _git_clone()
{
  git clone $1 $2/`basename $1`
}

# wrapper of wget
function _wget()
{
  wget $1 -P $2/

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
}

function get_project_03()
{
  local project=03
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/sako35/SoundDirectionRTC2 $project_src

  # get documents
  mv $project_src/*/*.pdf $project_doc/

  # get utility tools
}

function get_project_04()
{
  local project=04
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/Sakakibara-Hiroyuki/openRTM2016_04 $project_src

  # get documents
  mv $project_src/*/*.pdf $project_doc/

  # get utility tools
}

function get_project_05()
{
  local project=05
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/MatsudaR/RaspberryPi-Arduino-Duo-RTC $project_src

  # get documents
  # get utility tools
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
}

function get_project_07()
{
  local project=07
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  # get documents
  # get utility tools
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
}

function get_project_12()
{
  local project=12
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  # get documents
  # get utility tools
}

function get_project_13()
{
  local project=13
  local project_src=$project/src
  local project_doc=$project/doc
  local project_util=$project/util

  # get source code
  _git_clone https://github.com/mediart-C/Magicalight.git $project_src

  # get documents
  mv $project_src/*/*.pdf $project_doc/

  # get utility tools
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
  echo "--> Start PROJECT_$i"
  cleanup_project $i
  get_project_$i
  analyse_project $i
done

cat */summary.txt > summary_`date +%Y%m%d`.txt

exit 0

