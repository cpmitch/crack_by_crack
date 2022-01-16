#!/bin/bash
#
# 1-May-2018   version 01 Forked from countv3_allaz.sh for purpose of scripting aircrack-ng
#              attacks on structured hex wordlists.
# 28-Apr-2017: Modifying this to allow pyrit to work on hexadecimal named files such as:
#              61.txt (which contains a bunch of passwors starting with a)
#              Introducing this hiedous line:
#              john -w:$pathToHexBaseDir/$wordListDir/$hexVal.txt --rules:$johnRules -stdout | aircrack-ng -w - -b $BSSID -l $ESSID_key.txt $pcapFile
#
#              Usage:
#              ./crack_airc.sh <wordListDir> <pcapFile>
#
# 2-May-2018:  Cleaning up the markers fiasco. It's currently too messy so the idea is to
#              consolidate markers in a new ./markers directory. Easy, right?
# 3-May-2018:  More granularity in the markers, specifically the john rule used.
#
# 8-May-2018:  Tons of minor fixes and cosmetic upgrades here & there.
#
# 8-May-2018:  Adding crack.cfg file support.
#
# 9-May-2018:  Adding extra grep statement to filter out less than 8 strings fed into aircrack-ng
#
# 27-May-2018: Added CHECKFORKEY to keep things from getting out of hand if in fact by dumb luck
#              we actually found a key.
#
# 21-Sep-2018: Added check to fail if you did not specify a .pcap file. This happens when you have
#              been away for some time and need reminders on how to use this file!
#              Also added '&' at the end of the sendEmail statements to hurry things up if and when
#              the interwebs are down or unavailable, thus saving you about 60 seconds of your life.
#
# 30-Oct-2018: Added a basic timestamp to text messages.
#
# 26-Jul-2019: Major re-design with wordlist arguments moved to command-line not the config.cfg file.
#              ./crack_aircv3.sh file.cap english Korelogic1234Num 
#
# 02-Jul-2020: Added new check for john rule. PAUSE the script if the john rule is not detected in
#              file /etc/john/john.conf
#              Also cleaned up the subject line, removing the $hexVal from SENDEMAILALERT :
#                     -u Subject $HOSTNAME loop "$hexVal" \
#              Also tighten up the logging a bit.
#
# 11-Jul-2020: Added new check to see if john is sane. If it is NOT sane, collect RC=1.
#
# 02-Aug-2020: Now forking into semi-new project attempting to interate with two loops, inside and outside. 
#
# 07-Aug-2020: Significant write and re-wrires finally got this idea up & running.
#
# 11-Dec-2020: Test and pause if the text file 'SeparatorFilename' is found missing.
#              Extra logging for easier reading.
#
# 08-Feb-2021: Congrats Tom Brady on Superbowl #7 you are GOAT.
#              Added a bit more logging enhancements.
#
# 15-Oct-2021: Yet more refinements
#
# 25-Oct-2021: Place check for combinator3.bin from hashcat-utils to pause if not found.
#              Install with: sudo apt install hashcat-utils
#
# 28-Oct-2021: Subtle change in logging
#
##################################################################################################
#
##
if [ $# -ne 5 ] ; then
   echo "$0: Requires capFile msWordlist separatorFile.txt lsWordlist JohnRule."
   exit 139
fi
HOMEP=.
HOSTNAME=$('hostname')
# ESSID="Homenet2017"
# BSSID=F4:6B:EF:FD:D3:BE
FILE1=$1
if [ ! -e $FILE1 ] ; then
   echo "I'm looking for file: $FILE1, where is it?"
   echo "PCAP file not found, done with your nonsense."
   exit 139
fi

SeparatorFilename=$3
if [ ! -e $SeparatorFilename ] ; then
   echo "I'm looking for file: $SeparatorFilename, where is it?"
   echo "Text separator file not found, pausing..."
   touch ./pause
fi


pathToHex=./hex
pathToMarkers=./markers
CCLIST="t"
KEY="0000000000"
MESSAGE="Please check findings "
RC1=-91
RC2=92
RC3=93
SUCCESSMSGSINMASTERLOG=0
NEWCHECKFORSUCCESS=0
CRUNCHLOWVAL=8
CRUNCHHIGHVAL=8
NUMOFKEYS=175760000
msHexVal=1
lsHexVal=1

pathToHexBaseDir=$pathToBaseDir/$pathToHex
# pathToBaseDir=/root/Desktop/caps/
# pathToBaseDir=/root/caps/
# pathToHexBaseDir=$pathToBaseDir/$pathToHex
# pathToHexBaseDir=$pathToBaseDir/$pathToHex
# wordListDir=$1
# johnRules=None
# johnRules=Wordlist
# johnRules=Extra
# johnRules=Single
# johnRules=Jumbo
InProgress=InProgress
pcapFile=$1
# middleFile=./middleFile.txt
count=0
sendEmailFromUsername=""
sendEmailFromPassword=""
sendEmailFromEmail=""
sendEmailToEmail=""

msWordListDir=$2

shortSeparatorFilename=$(echo $SeparatorFilename | awk -F. '{ print $1 }')
lsWordListDir=$4
johnRules=$5

function get_time () {
   num=$1
   mins=0
   hours=0
   days=0
   if ((num>59)) ; then
   ((sec=num % 60))
   ((num=num/60))
   if ((num>59)) ; then
         ((mins=num%60))
         ((num=num/60))
         if ((num>23)) ; then
             ((hours=num%24))
             ((days=num/24))
         else
            ((hours=num))
         fi
     else
         ((mins=num))
     fi
   else
      ((sec=num))
   fi
   ## Now: $days $hours $mins $sec all ready to go...
}

getScriptStartDate (){

   STARTDATE1="2014-10-18 22:16:30"
   STARTDATE2="2014-10-18 22:16:31"
   until [ "$STARTDATE1" == "$STARTDATE2" ] ; do
      STARTDATE1="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
      sleep 0.100000
      STARTDATE2="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
   done
   scriptStartDate=$STARTDATE1
}

getScriptEndDate (){

   ENDDATE1="2014-10-18 22:16:30"
   ENDDATE2="2014-10-18 22:16:31"
   until [ "$ENDDATE1" == "$ENDDATE2" ] ; do
      ENDDATE1="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
      sleep 0.100000
      ENDDATE2="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
   done
   scriptEndDate=$ENDDATE1
}
getMSStartDate (){

   STARTDATE1="2014-10-18 22:16:30"
   STARTDATE2="2014-10-18 22:16:31"
   until [ "$STARTDATE1" == "$STARTDATE2" ] ; do
      STARTDATE1="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
      sleep 0.100000
      STARTDATE2="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
   done
   msStartDate=$STARTDATE1
}

getMSEndDate (){

   ENDDATE1="2014-10-18 22:16:30"
   ENDDATE2="2014-10-18 22:16:31"
   until [ "$ENDDATE1" == "$ENDDATE2" ] ; do
      ENDDATE1="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
      sleep 0.100000
      ENDDATE2="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
   done
   msEndDate=$ENDDATE1
}

getSTARTDATE (){

   STARTDATE1="2014-10-18 22:16:30"
   STARTDATE2="2014-10-18 22:16:31"
   until [ "$STARTDATE1" == "$STARTDATE2" ] ; do
      STARTDATE1="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
      sleep 0.100000
      STARTDATE2="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
   done
   STARTDATE=$STARTDATE1
}

getENDDATE (){

   ENDDATE1="2014-10-18 22:16:30"
   ENDDATE2="2014-10-18 22:16:31"
   until [ "$ENDDATE1" == "$ENDDATE2" ] ; do
      ENDDATE1="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
      sleep 0.100000
      ENDDATE2="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
   done
   ENDDATE=$ENDDATE1
}

SENDEMAILALERT ()
{
   if [ -e $HOMEP/sendEmail ] ; then
      sendEmail -xu $sendEmailFromUsername -xp $sendEmailFromPassword \
      -f $sendEmailFromEmail \
      -t $sendEmailToEmail,$CCLIST \
      -u Subject $HOSTNAME loop \
      -m $MESSAGE \
      -o tls=yes \
      -s smtp.gmail.com:587 &
   fi
}

CHECKFORPAUSE ()
{
      if [ -e $HOMEP/pause ] ; then
         echo "=PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in $HOMEP/, so pausing..."
         echo "=PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in $HOMEP/, so pausing..." >> $pathToBaseDir/master_log.txt
         echo "<BR>=PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in $HOMEP/, so pausing..." >> $pathToBaseDir/"$HOSTNAME".txt
      fi
      while [ -e $HOMEP/pause ] ; do
         echo -n "."
         sleep 30
   done
}

CHECKFORLOCALPAUSE ()
{
      if [ -e ../pause ] ; then
         echo "=LOCAL PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in ../, so pausing..."
         echo "=LOCAL PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in ../, so pausing..." >> $pathToBaseDir/master_log.txt
         echo "<BR>=LOCAL PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in ../, so pausing..." >> $pathToBaseDir/"$HOSTNAME".txt
      fi
      while [ -e ../pause ] ; do
         echo -n "."
         sleep 30
   done
}

CHECKFORPAUSE20 ()
{
   ### New check for pause20 added 05-Aug-2020... ###
   if ( [ $msHexVal == 20 ] && [ $lsHexVal == 20 ] ) ; then
      if [ -e $HOMEP/pause20 ] ; then
         echo "=PAUS20 $(date +%a) $(date +%D) $(date +%T) Pause20 marker found in $HOMEP/, so pausing..."
         echo "=PAUS20 $(date +%a) $(date +%D) $(date +%T) Pause20 marker found in $HOMEP/, so pausing..." >> $pathToBaseDir/master_log.txt
         echo "<BR>=PAUS20 $(date +%a) $(date +%D) $(date +%T) Pause20 marker found in $HOMEP/, so pausing..." >> $pathToBaseDir/"$HOSTNAME".txt
      fi
      while [ -e $HOMEP/pause20 ] ; do
         echo -n "."
         sleep 30
      done
   fi  
}

CHECKFORSTOP20 ()
{
   ### New check for stop20 added 11-Aug-2020... ###
   if ( [ $msHexVal == 20 ] && [ $lsHexVal == 20 ] ) ; then
      while [ -e $HOMEP/stop20 ] ; do
         echo "=STOP20 $(date +%a) $(date +%D) $(date +%T) Stop20 marker found in $HOMEP/, so stopping..."
         echo "=STOP20 $(date +%a) $(date +%D) $(date +%T) Stop20 marker found in $HOMEP/, so stopping..." >> $pathToBaseDir/master_log.txt
         echo "<BR>=STOP20 $(date +%a) $(date +%D) $(date +%T) Stop20 marker found in $HOMEP/, so stopping..." >> $pathToBaseDir/"$HOSTNAME".txt
         rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
         rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress
         rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
         rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"
         exit 0
      done
   fi  
}

CHECKFORSTOP ()
{
   while [ -e $HOMEP/stop ] ; do
      echo "=STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in $HOMEP/, so stopping..."
      echo "=STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in $HOMEP/, so stopping..." >> $pathToBaseDir/master_log.txt
      echo "<BR>=STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in $HOMEP/, so stopping..." >> $pathToBaseDir/"$HOSTNAME".txt
      rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
      rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress
      rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
      rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"
      exit 0
   done
}

CHECKFORLOCALSTOP ()
{
   while [ -e ../stop ] ; do
      echo "=LOCAL STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in ../, so stopping..."
      echo "=LOCAL STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in ../, so stopping..." >> $pathToBaseDir/master_log.txt
      echo "<BR>=LOCAL STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in ../, so stopping..." >> $pathToBaseDir/"$HOSTNAME".txt
      rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
      rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress
      rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
      rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"
      exit 0
   done
}

WRITENOTHING ()
{
   while [ -e $HOMEP/go ] ; do
     # echo "This does nothing more than write a tiny file, and then immediately erase same..."
     touch $HOMEP/winner
     sleep 0.1500
     rm $HOMEP/winner
     sleep 0.1500
   done
} 

CHECKFORKEY ()
{
   if [ -e $HOMEP/"$ESSID"_key.txt ] ; then
      echo "=STOP $(date +%a) $(date +%D) $(date +%T) Key found in $HOMEP/, so stopping..."
      echo "=STOP $(date +%a) $(date +%D) $(date +%T) Key found in $HOMEP/, so stopping..." >> $pathToBaseDir/master_log.txt
      echo "<BR>=STOP $(date +%a) $(date +%D) $(date +%T) Key found in $HOMEP/, so stopping..." >> $pathToBaseDir/"$HOSTNAME".txt
      rm ./go
      touch ./stop
      exit 0
   fi
}

checkForJohnRule ()
{
   egrep $johnRules"]" /etc/john/john.conf | grep -v include
   RC=$?
   case $RC in
      0) echo "John rule $johnRules found in /etc/john/john.conf so proceed..."
         ;;
      *) echo "John rule NOT FOUND $johnRules , pausing."
         MESSAGE="PAUSE John rule not found '$ESSID' '$wordListDir' '$johnRules' looping '$(date +%R)'."
         SENDEMAILALERT
         touch ./pause
         # exit 139
         sleep 2
         ;;
   esac
}

checkForMsWordListDirhexVal ()
{
echo "Checking for most significant hex value: $pathToHexBaseDir/$msWordListDir/$msHexVal".txt" ..."
if [ ! -e $pathToHexBaseDir/$msWordListDir/$msHexVal".txt" ] ; then
   echo "Most significant Hex file NOT FOUND $pathToHexBaseDir/$msWordListDir/$msHexVal.txt , local stopping."
   MESSAGE="LOCAL STOP most significant file not found $pathToHexBaseDir/$msWordListDir/$msHexVal.txt '$ESSID' '$johnRules' looping '$(date +%R)'."
   SENDEMAILALERT
   touch ../stop
   rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
   echo $MESSAGE > ../stop
   exit 139

fi
}

checkForLsWordListDirhexVal ()
{
echo "Checking for least significant hex value: $pathToHexBaseDir/$lsWordListDir/$lsHexVal".txt" ..."
if [ ! -e $pathToHexBaseDir/$lsWordListDir/$lsHexVal".txt" ] ; then
   echo "Least significant Hex file NOT FOUND $pathToHexBaseDir/$lsWordListDir/$lsHexVal.txt , local stopping."
   MESSAGE="LOCAL STOP least significant file not found $pathToHexBaseDir/$lsWordListDir/$lsHexVal.txt '$ESSID' '$johnRules' looping '$(date +%R)'."
   SENDEMAILALERT
   touch ../stop
   rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
   echo $MESSAGE > ../stop
   rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
   rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
   rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"
   exit 139
   # sleep 3
fi
}

checkForMsWordListDir ()
{
echo "Checking for most significant hex directory: $pathToHexBaseDir/$msWordListDir ..."
if [ ! -e $pathToHexBaseDir/$msWordListDir ] ; then
   echo "Most significant hex directory NOT FOUND $pathToHexBaseDir/$msWordListDir , local stopping."
   MESSAGE="LOCAL STOP Most significant dir not found $pathToHexBaseDir/$msWordListDir '$ESSID' '$msWordListDir' '$johnRules' looping '$(date +%R)'."
   SENDEMAILALERT
   touch ../stop
   rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
   echo $MESSAGE > ../stop
   exit 139
   # sleep 3
fi
}

checkForLsWordListDir ()
{
echo "Checking for least significant hex directory: $pathToHexBaseDir/$lsWordListDir ..."
if [ ! -e $pathToHexBaseDir/$lsWordListDir ] ; then
   echo "Least significant hex directory NOT FOUND $pathToHexBaseDir/$lsWordListDir , local stopping."
   MESSAGE="LOCAL STOP Least significant dir not found $pathToHexBaseDir/$lsWordListDir '$ESSID' '$lsWordListDir' '$johnRules' looping '$(date +%R)'."
   SENDEMAILALERT
   touch ../stop
   rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
   echo $MESSAGE > ../stop
   rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
   rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
   rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"
   exit 139
   # sleep 3
fi
}

checkForJohnSanity ()
{
   echo -n "Checking for john sanity..."
   john -w:/etc/john/john.conf --rules:None --stdout
   RC=$?
   case $RC in
      0) echo "John appears sane, so proceed..."
         ;;
      *) echo "John NOT sane, pausing."
         MESSAGE="LOCAL PAUSE John has a problem, please debug '$ESSID' '$wordListDir' '$johnRules' looping '$(date +%R)'."
         SENDEMAILALERT
         touch ../pause
         echo $MESSAGE > ../pause
         # exit 139
         sleep 3
         ;;
   esac
}

if [ ! -e $HOMEP/go ] ; then
   echo "=NoGo $(date +%a) $(date +%D) $(date +%T) go marker found absent, exiting..."
   echo "=NoGo $(date +%a) $(date +%D) $(date +%T) go marker found absent, exiting..." >> $pathToBaseDir/master_log.txt
   echo "<BR>=NoGo $(date +%a) $(date +%D) $(date +%T) go marker found absent, exiting..." >> $pathToBaseDir/"$HOSTNAME".txt
   exit 139
fi

if [ -e ./config.cfg ] ; then
   echo "Found config.cfg file, reading vars..."
   pathToBaseDir=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 pathToBaseDir | awk '{ print $2 }')   
   pathToHexBaseDir=$pathToBaseDir/$pathToHex
   echo "Your var pathToBaseDir = $pathToBaseDir so moving on..."
   ESSID=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 ESSID | awk '{ print $2 }')
   BSSID=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 BSSID | awk '{ print $2 }')
   # wordListDir=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 wordListDirRules | awk '{ print $2 }')   
   # johnRules=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 wordListDirRules | awk '{ print $3}')
   crackTool=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 crackTool | awk '{ print $2 }')
   CCLIST=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 CCLIST | awk '{ print $2 }')
   sendEmailFromUsername=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 sendEmailFromUsername | awk '{ print $2 }')
   sendEmailFromPassword=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 sendEmailFromPassword | awk '{ print $2 }')
   sendEmailFromEmail=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 sendEmailFromEmail | awk '{ print $2 }')
   sendEmailToEmail=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 sendEmailToEmail | awk '{ print $2 }')
else
   echo "config.cfg doesn't exist, nothing to do here..."
   exit 0
fi

if [ ! -e /usr/share/hashcat-utils/combinator3.bin ] ; then
   MESSAGE="No hashcat-utils combinator3.bin found. Do this: sudo apt install hashcat-utils"
   echo "No hashcat-utils combinator3.bin found. Do this: sudo apt install hashcat-utils"
   echo $MESSAGE > ../pause
   # touch ../pause
fi

if [ "$pathToBaseDir" == "" ] ; then
   echo "Did not parse and find pathToBaseDir, exiting."
   exit 0
fi

if [ "$ESSID" == "" ] ; then
   echo "Did not parse and find ESSID, exiting."
   exit 0
fi

if [ "$BSSID" == "" ] ; then
   echo "Did not parse and find BSSID, exiting."
   exit 0
fi

if [ "$johnRules" == "" ] ; then
   echo "Did not parse and find johnRules, exiting."
   exit 0
fi

if [ "$crackTool" == "" ] ; then
   echo "Did not parse and find crackTool, exiting."
   exit 0
fi

if [ ! -e $pathToMarkers ] ; then
   echo "Did not find markers directory, so creating it..."
   mkdir $pathToMarkers
fi
# Below lines designed to prevent a rush of TXT when ./stop found...
CHECKFORPAUSE
CHECKFORSTOP
CHECKFORLOCALPAUSE
CHECKFORLOCALSTOP
CHECKFORPAUSE20
CHECKFORSTOP20
CHECKFORKEY
ELAPSEDSECONDS=0
ELAPSEDMINS=0

echo " "
echo " " >> $HOMEP/master_log.txt
echo " " >> $HOMEP/"$HOSTNAME".txt

# SUCCESSMSGSINMASTERLOG=$(cat $HOMEP/master_log.txt | egrep 'The PSK is |The password is ' | wc -l)
echo "+STRT $(date +%a) $(date +%D) $(date +%T) Start another aircack cycle..."
echo "+STRT $(date +%a) $(date +%D) $(date +%T) Start another aircack cycle..." >> $pathToBaseDir/master_log.txt
echo "<BR>+STRT $(date +%a) $(date +%D) $(date +%T) Start another aircack cycle... " >> $pathToBaseDir/"$HOSTNAME".txt

CURRENTDATE="$(date +%a)-$(date '+%d')-$(date '+%b')-$(date '+%Y')--$(date '+%H'):$(date '+%M'):$(date '+%S')"
echo "**** Starting testing $CURRENTDATE ******************************"

# MESSAGE="Start of '$ESSID' '$johnRules' '$1' looping."
checkForJohnSanity
MESSAGE="Start of '$ESSID' '$msWordListDir' '$shortSeparatorFilename' '$lsWordListDir' '$johnRules' looping '$(date +%R)'."
SENDEMAILALERT
SeparatorFilenameCount=$(cat $HOMEP/$SeparatorFilename | wc -l)

getScriptStartDate
echo "Script Start Date: $scriptStartDate '$ESSID' '$msWordListDir' '$shortSeparatorFilename' '$lsWordListDir' '$johnRules' by $HOSTNAME " >> $pathToBaseDir/"$HOSTNAME".txt
echo "Script Start Date: $scriptStartDate '$ESSID' '$msWordListDir' '$shortSeparatorFilename' '$lsWordListDir' '$johnRules' by $HOSTNAME " >> ./master_log.txt

echo -n "ms and ls: "
# Below is for each nad every entry...
for msHexVal in 20 21 22 23 24 25 26 27 28 29 2A 2B 2C 2D 2E 2F \
                30 31 32 33 34 35 36 37 38 39 3A 3B 3C 3D 3E 3F \
                40 41 42 43 44 45 46 47 48 49 4A 4B 4C 4D 4E 4F \
                50 51 52 53 54 55 56 57 58 59 5A 5B 5C 5D 5E 5F \
                60 61 62 63 64 65 66 67 68 69 6A 6B 6C 6D 6E 6F \
                70 71 72 73 74 75 76 77 78 79 7A 7B 7C 7D 7E
do
   
   checkForMsWordListDir
   checkForMsWordListDirhexVal
   getMSStartDate
   # msEasyHexVal=$(echo -n 0x$msHexVal | xxd -r)
   msCount=$(cat $pathToHexBaseDir/$msWordListDir/$msHexVal.txt | wc -l)
   msIntervalSeconds=0
   msIntervalMinutes=0
   msIntervalHours=0

   for lsHexVal in 20 21 22 23 24 25 26 27 28 29 2A 2B 2C 2D 2E 2F \
                   30 31 32 33 34 35 36 37 38 39 3A 3B 3C 3D 3E 3F \
                   40 41 42 43 44 45 46 47 48 49 4A 4B 4C 4D 4E 4F \
                   50 51 52 53 54 55 56 57 58 59 5A 5B 5C 5D 5E 5F \
                   60 61 62 63 64 65 66 67 68 69 6A 6B 6C 6D 6E 6F \
                   70 71 72 73 74 75 76 77 78 79 7A 7B 7C 7D 7E
   do

      # touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
      # echo "Check for marker $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"
      # echo "Check for marker $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_*_"$InProgress"
      if [ ! -e $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress ] && \
         [ ! -e $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules ] && \
         [ ! -e $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt" ] && \
         [ ! -e $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt" ] && \
         [ ! -e $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_*_"$InProgress ] ; then

         touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress
         # touch $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
         # touch $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"
         touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
         # sleep 0.1
         echo "Got past the check meaning no marker found!"
         # touch $HOMEP/$pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules
         # touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
         checkForLsWordListDir
         checkForLsWordListDirhexVal
         CHECKFORPAUSE
         CHECKFORSTOP
         CHECKFORLOCALPAUSE
         CHECKFORLOCALSTOP
         CHECKFORPAUSE20
         CHECKFORSTOP20
         CHECKFORKEY

         echo -n "(" >> $pathToBaseDir/"$HOSTNAME".txt
         echo -n "(" >> ./master_log.txt
         echo -n "$msHexVal-$lsHexVal $HOSTNAME " >> $pathToBaseDir/"$HOSTNAME".txt
         echo -n "$msHexVal-$lsHexVal $HOSTNAME " >> ./master_log.txt

         if [ $msCount -gt 0 ] ; then
            echo "msCount $msCount is greater than zero."

            lsCount=$(cat $pathToHexBaseDir/$lsWordListDir/$lsHexVal.txt | wc -l)

            if [ $lsCount -gt 0 ] ; then
               echo "lsCount $lsCount is greater than zero."
               echo "+++$(date +%a) $(date +%D) $(date +%T) Start $crackTool on AP=$ESSID, MAC=$BSSID, using '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' file=$FILE1 count=$((msCount*lsCount*SeparatorFilenameCount)) . ++++"
               echo "+++$(date +%a) $(date +%D) $(date +%T) Start $crackTool on AP=$ESSID, MAC=$BSSID, using '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' file=$FILE1 count=$((msCount*lsCount*SeparatorFilenameCount)) . ++++" >> $pathToBaseDir/master_log.txt
               # echo -n "$msHexVal-$lsHexVal " >> $pathToBaseDir/"$HOSTNAME".txt

            fi # Check for lsCount greater than 0.
         fi # Check for msCount greater than 0.
            #######################
            ## echo -n "$msHexVal-$lsHexVal" >> $pathToBaseDir/"$HOSTNAME".txt
            ## echo -n "$msHexVal-$lsHexVal" >> ./master_log.txt
            ####################### Below if clause is candidate for removal - already checked this condition Above.
            if [ $msCount -gt 0 ] && [ $lsCount -gt 0 ] ; then
               echo "Both $msCount and $lsCount greater than 0, proceeding..."
               getSTARTDATE

               /usr/share/hashcat-utils/combinator3.bin $pathToHexBaseDir/$msWordListDir/$msHexVal".txt" $SeparatorFilename $pathToHexBaseDir/$lsWordListDir/$lsHexVal".txt" > $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
               cat $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt" | sort -u > $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"

               # exit 0
               # echo "Using $msHexVal-$lsHexVal "
               # echo "Using $pathToHexBaseDir/$wordListDir/$hexVal.txt ..."

               case $crackTool in

                     aircrack-ng) echo "Using $msHexVal-$lsHexVal "
                                  john -w:$HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt" --rules:$johnRules -stdout | grep '^.\{8\}' | aircrack-ng -w - -b $BSSID -l $ESSID"_key.txt" $pcapFile
                                  RC1=$?
                                  touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules
                                  rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
                                  rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"
                                  rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
                                  rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress
                                  ;;
                           pyrit) echo "Using $msHexVal-$lsHexVal "
                                  john -w:$HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt" --rules:$johnRules -stdout | grep '^.\{8\}' | pyrit -i - -b $BSSID -o $ESSID"_key.txt" -r $pcapFile --all-handshakes attack_passthrough
                                  RC1=$?
                                  touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules
                                  rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
                                  rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"
                                  rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
                                  rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress
                                  ;;
                               *) echo "=NoGo $(date +%a) $(date +%D) $(date +%T) crack tool not found, exiting..."
                                  echo "<BR>=NoGo $(date +%a) $(date +%D) $(date +%T) crack tool not found, exiting..." >> $pathToBaseDir/master_log.txt
                                  echo "<BR>=NoGo $(date +%a) $(date +%D) $(date +%T) crack tool not found, exiting..." >> $pathToBaseDir/"$HOSTNAME".txt
                                  rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
                                  rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress
                                  exit 139
                                  ;;
               esac

               getENDDATE

               sec_old=$(date -d "$STARTDATE" +%s)
               sec_new=$(date -d "$ENDDATE" +%s)
               ELAPSEDSECONDS=$(( sec_new - sec_old ))
               msIntervalSeconds=$(( msIntervalSeconds + ELAPSEDSECONDS ))

            fi # msCount && lsCount both greater than 0
            ####################### Above if clause is candidate for removal - already checked this condition Above.
            # touch $HOMEP/$pathToMarkers/$hexVal"_$wordListDir"_$johnRules
            # touch $HOMEP/$msWordListDir"-"$msHexVal"-middleFile-"$lsWordListDir"-"$lsHexVal"__"$johnRules
            # touch $HOMEP/$pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules

            # sleep 0.1000

            if [ -e $HOMEP/"$ESSID"_key.txt ] ; then
                # This is the way to check if aircrack-ng has found the key.
                # Use aircrack-ng -l $ESSID.txt switch to write to a file.
                touch $HOMEP/sendEmail
                KEY=$(cat $HOMEP/"$ESSID"_key.txt)
                MESSAGE="Please check findings '$KEY'"
                SENDEMAILALERT
                echo "=KEY- $(date +%a) $(date +%D) $(date +%T) =====Completed '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' found key '$KEY' end ====="
                echo "=KEY- $(date +%a) $(date +%D) $(date +%T) =====Completed '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' found key '$KEY' end =====" >> $pathToBaseDir/master_log.txt
                # echo "<BR>=KEY- $(date +%a) $(date +%D) $(date +%T) =====Completed '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' found key '$KEY' end =====" >> $pathToBaseDir/"$HOSTNAME".txt
                echo -n " $ELAPSEDMINS $ELAPSEDSECONDS - $KEY)." >> $pathToBaseDir/"$HOSTNAME".txt
                # touch $HOMEP/$pathToMarkers/$hexVal"_$1"_$johnRules
                #### echo "#### wordListDirRules $wordListDir $johnRules" >> ./config.cfg
                rm $HOMEP/sendEmail
                rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
                rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress
                exit 0
            fi # Check for key file

            ###
            ### echo -n " $ELAPSEDMINS m $ELAPSEDSECONDS s)." >> $pathToBaseDir/"$HOSTNAME".txt
            if (( $ELAPSEDSECONDS < 1 )) ; then
               # echo -n "(" >> $pathToBaseDir/"$HOSTNAME".txt
               # echo -n "(" >> ./master_log.txt
               # echo -n "$msHexVal-$lsHexVal" >> $pathToBaseDir/"$HOSTNAME".txt
               # echo -n "$msHexVal-$lsHexVal" >> ./master_log.txt
               echo -n ")." >> $pathToBaseDir/"$HOSTNAME".txt
               echo -n ")." >> ./master_log.txt
            else
               # echo -n "(" >> $pathToBaseDir/"$HOSTNAME".txt
               # echo -n "(" >> ./master_log.txt
               # echo -n "$msHexVal-$lsHexVal $HOSTNAME "$(($ELAPSEDSECONDS/3600))"h "$(($ELAPSEDSECONDS%3600/60))"m "$(($ELAPSEDSECONDS%60)) >> $pathToBaseDir/"$HOSTNAME".txt
               # echo -n "$msHexVal-$lsHexVal $HOSTNAME "$(($ELAPSEDSECONDS/3600))"h "$(($ELAPSEDSECONDS%3600/60))"m "$(($ELAPSEDSECONDS%60)) >> ./master_log.txt
               echo -n $(($ELAPSEDSECONDS/3600))"h "$(($ELAPSEDSECONDS%3600/60))"m "$(($ELAPSEDSECONDS%60)) >> $pathToBaseDir/"$HOSTNAME".txt
               echo -n $(($ELAPSEDSECONDS/3600))"h "$(($ELAPSEDSECONDS%3600/60))"m "$(($ELAPSEDSECONDS%60)) >> ./master_log.txt
               echo -n ")." >> $pathToBaseDir/"$HOSTNAME".txt
               echo -n ")." >> ./master_log.txt
            fi
            ###
            ### Below 1 line is not completely necessary but will help me debug if something is run twice:
            # touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME
            ### Above 1 line can be deleted in the future if no doubles are detected.
            ## touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules
            ##    rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress

      else # this is run if the marker file was found....
            ## rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
            ## rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME
            echo "=MRK- $(date +%a) $(date +%D) $(date +%T) ==== Completed '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' Marker found, has this been attempted already?"
            echo "<BR>=MRK- $(date +%a) $(date +%D) $(date +%T) ==== Completed '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' Marker found, has this been attempted already?" >> $pathToBaseDir/master_log.txt
            # echo "<BR>=MRK- $(date +%a) $(date +%D) $(date +%T) ==== Completed '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' Marker found, has this been attempted already?" >> $pathToBaseDir/"$HOSTNAME".txt
            echo -n "(M)." >> $pathToBaseDir/"$HOSTNAME".txt
            echo -n "(M)." >> ./master_log.txt
            # rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
            # rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress

      fi # Check for marker $HOMEP/$pathToMarkers/$msHexVal"-"$shortSeparatorFilename"-"$lsHexVal"_"$msWordListDir"-"$lsWordListDir"_"$wordListDir"_"$johnRules

            echo "=$(date +%a) $(date +%D) $(date +%T) ==== Completed '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' cycle in $(($ELAPSEDSECONDS%3600/60)) m $(($ELAPSEDSECONDS%60)) s file=$FILE1  found '$NEWCHECKFORSUCCESS', move along ====="
            echo "=$(date +%a) $(date +%D) $(date +%T) ==== Completed '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' cycle in $(($ELAPSEDSECONDS%3600/60)) m $(($ELAPSEDSECONDS%60)) s file=$FILE1  found '$NEWCHECKFORSUCCESS', move along =====" >> $pathToBaseDir/master_log.txt
            # echo "<BR>=$(date +%a) $(date +%D) $(date +%T) ==== Completed '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules' cycle in $ELAPSEDMINS m ($ELAPSEDSECONDS s), rule=$johnRules file=$FILE1 found '$NEWCHECKFORSUCCESS', move along =====" >> $pathToBaseDir/"$HOSTNAME".txt
            # echo -n " $ELAPSEDMINS m $modElapsedSeconds s)." >> $pathToBaseDir/"$HOSTNAME".txt
            ELAPSEDSECONDS=0
            ELAPSEDMINS=0
            echo " "
            echo " "
            # sleep 0.1000
            # CHECKFORPAUSE
            ## CHECKFORSTOP
            CHECKFORPAUSE
            CHECKFORSTOP
            CHECKFORLOCALPAUSE
            CHECKFORLOCALSTOP
            CHECKFORPAUSE20
            CHECKFORSTOP20

            ### Below 1 line is not completely necessary but will help me debug if something is run twice:
            # touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME
            ### Above 1 line can be deleted in the future if no doubles are detected.
            touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules
            #### Below 2 lines are run against temp files written by competing process and should not be deleted! Right?!?!?
            # rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp.txt"
            # rm $HOMEP/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_temp1.txt"
            ## touch $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME
            ## Below 2 lines moved up to cracking section, since when found marker below is still run, slowing things down...
            # rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$HOSTNAME"_"$InProgress
            # rm $pathToMarkers/$msWordListDir"-"$msHexVal"-"$shortSeparatorFilename"-"$lsWordListDir"-"$lsHexVal"__"$johnRules"_"$InProgress

   done # for lsHexVal looping
   getMSEndDate
   sec_old=$(date -d "$msStartDate" +%s)
   sec_new=$(date -d "$msEndDate" +%s)
   msIntervalSeconds=$(( sec_new - sec_old ))
   #########################################
   ### Below is the old math being replaced:
   ### modmsIntervalSeconds=$(( msIntervalSeconds % 60 ))
   ### msIntervalMins=$(( msIntervalSeconds % 60 )) 
   ### msIntervalHours=$(( msIntervalMins / 60 ))
   ### echo ".($msHexVal MS tot: $msIntervalHours h $msIntervalMins m $modmsIntervalSeconds s)" >> $pathToBaseDir/"$HOSTNAME".txt
   #########################################
   get_time $msIntervalSeconds
   echo ".($msHexVal MS tot: "$days"d "$hours"h "$mins"m "$sec"s for $ESSID '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules')" >> $pathToBaseDir/"$HOSTNAME".txt
   echo ".($msHexVal MS tot: "$days"d "$hours"h "$mins"m "$sec"s for $ESSID '$msWordListDir-$msHexVal-$shortSeparatorFilename-$lsWordListDir-$lsHexVal--$johnRules')" >> $pathToBaseDir/master_log.txt
   echo " " >> $pathToBaseDir/"$HOSTNAME".txt
done #### for msHexVal looping

getScriptEndDate

sec_old=$(date -d "$scriptStartDate" +%s)
sec_new=$(date -d "$scriptEndDate" +%s)
scriptIntervalSeconds=$(( sec_new - sec_old ))
#########################################
### Below is the old math being replaced:
### modscriptIntervalSeconds=$(( scriptIntervalSeconds % 60 ))
### scriptIntervalMins=$(( scriptIntervalSeconds / 60 ))
### scriptIntervalHours=$(( scriptIntervalMins / 60 ))
### echo ".(Script tot: $scriptIntervalHours h $scriptIntervalMins m $modscriptIntervalSeconds s)" >> $pathToBaseDir/"$HOSTNAME".txt
#########################################
get_time $scriptIntervalSeconds
# echo ".(Script tot: "$days"d "$hours"h "$mins"m "$sec"s)" >> $pathToBaseDir/"$HOSTNAME".txt
# echo "Script Start Date: $scriptStartDate  " >> $pathToBaseDir/"$HOSTNAME".txt
# echo "Script   End Date: $scriptEndDate  " >> $pathToBaseDir/"$HOSTNAME".txt
echo "Script   End Date: $scriptEndDate '$ESSID' '$msWordListDir' '$shortSeparatorFilename' '$lsWordListDir' '$johnRules' '$HOSTNAME' tot: "$days"d "$hours"h "$mins"m "$sec"s" >> $pathToBaseDir/"$HOSTNAME".txt
echo "Script   End Date: $scriptEndDate '$ESSID' '$msWordListDir' '$shortSeparatorFilename' '$lsWordListDir' '$johnRules' '$HOSTNAME' `tot: "$days"d "$hours"h "$mins"m "$sec"s >> ./master_log.txt

sleep .1000
# done # while exists go, do ... until looping
echo "=END- $(date +%a) $(date +%D) $(date +%T) Loop was exhausted, bye."
echo "=END- $(date +%a) $(date +%D) $(date +%T) Loop was exhausted, bye." >> $pathToBaseDir/master_log.txt
echo "=END- $(date +%a) $(date +%D) $(date +%T) Loop was exhausted, bye." >> ./master_log.txt
echo "<BR>=END- $(date +%a) $(date +%D) $(date +%T) Loop was exhausted, bye." >> $pathToBaseDir/"$HOSTNAME".txt
echo " " >> $pathToBaseDir/"$HOSTNAME".txt
echo " " >> ./master_log.txt
MESSAGE="End of '$ESSID' '$msWordListDir' $shortSeparatorFilename '$lsWordListDir' '$johnRules' looping '$(date +%R)'."
echo "#### $0 $FILE1 $msWordListDir $lsWordListDir $johnRules" >> ./config.cfg
SENDEMAILALERT
sleep 2
exit 0
