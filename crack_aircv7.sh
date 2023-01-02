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
# 11-Feb-2021: Added logging improvements.
#
# 12-Sep-2021: Added InProgress to markers supporting shared file system cracking. Also cleaned up logging by emphasizing local machine progress.
#              Added CHECKFORLOCALPAUSE and CHECKFORLOCALSTOP
#
# 14-Sep-2021: Added a few more markers and deleted one more.
#
# 22-Oct-2021: rm command commented out in else section preventing duplicate runs in clusters or 3+ machines
#
# 15-Jan-2022: Now placing username and password into config.cfg
#
# 03-Feb-2022: Reordering the logging to help it appear more appealing.
#
# 04-Feb-2022: Adding a cumulative elapsed time report after 7E completes.
#
##################################################################################################
#
##
if [ $# -ne 3 ] ; then
   echo "$0: Requires .cap wordlist ruleset."
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
hexVal=1
userId=$(whoami)
# pathToBaseDir=/root/Desktop/caps/
# pathToBaseDir=/root/caps/
pathToHexBaseDir=$pathToBaseDir/$pathToHex
# pathToHexBaseDir=$pathToBaseDir/$pathToHex
# wordListDir=$1
# johnRules=None
# johnRules=Wordlist
# johnRules=Extra
# johnRules=Single
# johnRules=Jumbo
InProgress=InProgress
pcapFile=$1
count=0
sendEmailFromUsername=""
sendEmailFromPassword=""
sendEmailFromEmail=""
sendEmailToEmail=""
scriptStartDate=""
scriptEndDate=""

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
      sleep 0.150000
      STARTDATE2="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
   done
   STARTDATE=$STARTDATE1
}

getENDDATE (){

   ENDDATE1="2014-10-18 22:16:30"
   ENDDATE2="2014-10-18 22:16:31"
   until [ "$ENDDATE1" == "$ENDDATE2" ] ; do
      ENDDATE1="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
      sleep 0.150000
      ENDDATE2="$(date '+%Y')-$(date '+%m')-$(date '+%d') $(date '+%H'):$(date '+%M'):$(date '+%S')" 
   done
   ENDDATE=$ENDDATE1
}

SENDEMAILALERT ()
{
      sendEmail -xu $sendEmailFromUsername -xp $sendEmailFromPassword \
      -f $sendEmailFromEmail \
      -t $sendEmailToEmail,$CCLIST \
      -u Subject $HOSTNAME loop \
      -m $MESSAGE \
      -o tls=yes \
      -s smtp.gmail.com:587 &

}

CHECKFORPAUSE ()
{
   if [ -e $HOMEP/pause ] ; then
      echo "=PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in $HOMEP/, so pausing.."
      echo "=PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in $HOMEP/, so pausing.." >> $pathToBaseDir/master_log.txt
      echo "=PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in $HOMEP/, so pausing.." >> ./master_log.txt
      echo "<BR>=PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in $HOMEP/, so pausing.." >> $pathToBaseDir/"$HOSTNAME".txt
   echo -n "." >> $pathToBaseDir/master_log.txt
   echo -n "." >> ./master_log.txt
   echo -n "." >> $pathToBaseDir/"$HOSTNAME".txt
   fi
   while [ -e $HOMEP/pause ] ; do
      echo -n "." >> ./master_log.txt
      echo -n "." >> ../master_log.txt
      echo -n "." >> ./"$HOSTNAME".txt
      sleep 60
   done
}

CHECKFORLOCALPAUSE ()
{
   if [ -e ../pause ] ; then
      echo "=Local PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in .. so pausing.."
      echo "=Local PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in .. so pausing.." >> $pathToBaseDir/master_log.txt
      echo "=Local PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in .. so pausing.." >> ./master_log.txt
      echo "<BR>=Local PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in .. so pausing.." >> $pathToBaseDir/"$HOSTNAME".txt
      echo "=Local PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in .. so pausing.." >> ./master_log.txt
      echo "<BR>=Local PAUS $(date +%a) $(date +%D) $(date +%T) Pause marker found in .. so pausing.." >> ../"$HOSTNAME".txt
   echo -n "." >> $pathToBaseDir/master_log.txt
   echo -n "." >> ./master_log.txt
   echo -n "." >> $pathToBaseDir/"$HOSTNAME".txt
   fi
   while [ -e ../pause ] ; do
      echo -n "." >> ./master_log.txt
      echo -n "." >> ./"$HOSTNAME".txt
      echo -n "." >> ../master_log.txt
      echo -n "." >> ../"$HOSTNAME".txt
      sleep 60
   done
}

CHECKFORSTOP ()
{
   while [ -e $HOMEP/stop ] ; do
      echo "=STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in $HOMEP/, so stopping..."
      echo "=STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in $HOMEP/, so stopping..." >> $pathToBaseDir/master_log.txt
      echo "=STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in $HOMEP/, so stopping..." >> ./master_log.txt
      echo "<BR>=STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in $HOMEP/, so stopping..." >> $pathToBaseDir/"$HOSTNAME".txt
   rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
   rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress
      exit 0
   done
}

CHECKFORLOCALSTOP ()
{
   while [ -e ../stop ] ; do
      echo "=Local STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in .. so stopping..."
      echo "=Local STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in .. so stopping..." >> $pathToBaseDir/master_log.txt
      echo "<BR>=Local STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in .. so stopping..." >> $pathToBaseDir/"$HOSTNAME".txt
      echo "=Local STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in .. so stopping..." >> ./master_log.txt
      echo "<BR>=Local STOP $(date +%a) $(date +%D) $(date +%T) Stop marker found in .. so stopping..." >> ../"$HOSTNAME".txt
   rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
   rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress
      exit 0
   done
}

CHECKFORPAUSE20 ()
{
   ### New check for pause20 added 05-Aug-2020... ###
   if ( [ $hexVal == 20 ] ) ; then
      if [ -e $HOMEP/pause20 ] ; then
         echo "=PAUS20 $(date +%a) $(date +%D) $(date +%T) Pause20 marker found in $HOMEP/, so pausing..."
         echo "=PAUS20 $(date +%a) $(date +%D) $(date +%T) Pause20 marker found in $HOMEP/, so pausing..." >> $pathToBaseDir/master_log.txt
         echo "=PAUS20 $(date +%a) $(date +%D) $(date +%T) Pause20 marker found in $HOMEP/, so pausing..." >> ./master_log.txt
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
   if ( [ $hexVal == 20 ] ) ; then
      while [ -e $HOMEP/stop20 ] ; do
         echo "=STOP20 $(date +%a) $(date +%D) $(date +%T) Stop20 marker found in $HOMEP/, so stopping..."
         echo "=STOP20 $(date +%a) $(date +%D) $(date +%T) Stop20 marker found in $HOMEP/, so stopping..." >> $pathToBaseDir/master_log.txt
         echo "=STOP20 $(date +%a) $(date +%D) $(date +%T) Stop20 marker found in $HOMEP/, so stopping..." >> ./master_log.txt
         echo "<BR>=STOP20 $(date +%a) $(date +%D) $(date +%T) Stop20 marker found in $HOMEP/, so stopping..." >> $pathToBaseDir/"$HOSTNAME".txt
   rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
   rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress
         exit 0
      done
   fi  
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
      echo "=STOP $(date +%a) $(date +%D) $(date +%T) Key found in $HOMEP/, so stopping..." >> ./master_log.txt
      echo "<BR>=STOP $(date +%a) $(date +%D) $(date +%T) Key found in $HOMEP/, so stopping..." >> $pathToBaseDir/"$HOSTNAME".txt
      rm ./go
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
         echo $MESSAGE > ./pause
         # exit 139
         sleep 3
         ;;
   esac
}

checkForWordListDir ()
{
echo "Checking for hex directory: $pathToHexBaseDir/$wordListDir ..."
if [ ! -e $pathToHexBaseDir/$wordListDir ] ; then
   echo "Hex dictionary NOT FOUND $pathToHexBaseDir/$wordListDir , pausing."
   MESSAGE="PAUSE DICT not found $pathToHexBaseDir/$wordListDir '$ESSID' '$wordListDir' '$johnRules' looping '$(date +%R)'."
   SENDEMAILALERT
   touch ./pause
   echo $MESSAGE > ./pause
   # exit 139
   sleep 3
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
         MESSAGE="PAUSE John has a problem, please debug '$ESSID' '$wordListDir' '$johnRules' looping '$(date +%R)'."
         SENDEMAILALERT
         touch ./pause
         echo $MESSAGE > ./pause
         # exit 139
         sleep 3
         ;;
   esac
}

# Begin main program loop...
# while [ -e $HOMEP/go ] ; do

if [ $# -ne 3 ] ; then
   echo "Did you forget? You need to specify a .pcap file!"
   exit 1
   echo "=STOP $(date +%a) $(date +%D) $(date +%T) No pcap file argument, how embarassing, so stopping..."
   echo "=STOP $(date +%a) $(date +%D) $(date +%T) No pcap file argument, how embarassing, so stopping..." >> $pathToBaseDir/master_log.txt
   echo "=STOP $(date +%a) $(date +%D) $(date +%T) No pcap file argument, how embarassing, so stopping..." >> ./master_log.txt
   echo "<BR>=STOP $(date +%a) $(date +%D) $(date +%T) No pcap file argument, how embarassing, so stopping..."  >> $pathToBaseDir/"$HOSTNAME".txt
fi

if [ -e ./config.cfg ] ; then
   echo "Found config.cfg file, reading vars..."
   pathToBaseDir=/home/$userId/caps  
   # pathToBaseDir=$(cat ./config.cfg | grep -Pv ^'\x23' | grep -m 1 pathToBaseDir | awk '{ print $2 }')   
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
wordListDir=$2
johnRules=$3

pathToHexBaseDir=$pathToBaseDir/$pathToHex

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

if [ "$wordListDir" == "" ] ; then
   echo "Did not parse and find wordListDir, exiting."
   exit 0
fi

# checkForWordListDir

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
   CHECKFORLOCALPAUSE
   CHECKFORLOCALSTOP
   CHECKFORPAUSE
   CHECKFORSTOP

   echo " "
   echo " " >> $HOMEP/master_log.txt
   # echo " " >> ./master_log.txt
   echo " " >> $HOMEP/"$HOSTNAME".txt

   # SUCCESSMSGSINMASTERLOG=$(cat $HOMEP/master_log.txt | egrep 'The PSK is |The password is ' | wc -l)
   echo "+STRT $(date +%a) $(date +%D) $(date +%T) Start another aircack cycle..."
   echo "+STRT $(date +%a) $(date +%D) $(date +%T) Start another aircack cycle..." >> $pathToBaseDir/master_log.txt
   # echo "+STRT $(date +%a) $(date +%D) $(date +%T) Start another aircack cycle..." >> ./master_log.txt
   echo "<BR>+STRT $(date +%a) $(date +%D) $(date +%T) Start another aircack cycle..." >> $pathToBaseDir/"$HOSTNAME".txt


   CURRENTDATE="$(date +%a)-$(date '+%d')-$(date '+%b')-$(date '+%Y')--$(date '+%H'):$(date '+%M'):$(date '+%S')"
   echo "**** Starting testing $CURRENTDATE ******************************"

   # MESSAGE="Start of '$ESSID' '$johnRules' '$1' looping."
   checkForJohnSanity
   MESSAGE="Start of '$ESSID' '$wordListDir' '$johnRules' looping '$(date +%R)'."
   getScriptStartDate
   SENDEMAILALERT

   # Below is for each nad every entry...
   for hexVal in 20 21 22 23 24 25 26 27 28 29 2A 2B 2C 2D 2E 2F \
                 30 31 32 33 34 35 36 37 38 39 3A 3B 3C 3D 3E 3F \
                 40 41 42 43 44 45 46 47 48 49 4A 4B 4C 4D 4E 4F \
                 50 51 52 53 54 55 56 57 58 59 5A 5B 5C 5D 5E 5F \
                 60 61 62 63 64 65 66 67 68 69 6A 6B 6C 6D 6E 6F \
                 70 71 72 73 74 75 76 77 78 79 7A 7B 7C 7D 7E
 
   do

   easyHexVal=$(echo -n 0x$hexVal | xxd -r)

   checkForWordListDir
   checkForJohnRule
   CHECKFORPAUSE20
   CHECKFORSTOP20
   CHECKFORLOCALPAUSE
   CHECKFORLOCALSTOP
   CHECKFORPAUSE
   CHECKFORSTOP
   CHECKFORKEY
  
if [ ! -e $HOMEP/go ] ; then
   echo "=NoGo $(date +%a) $(date +%D) $(date +%T) go marker found absent, exiting..."
   echo "=NoGo $(date +%a) $(date +%D) $(date +%T) go marker found absent, exiting..." >> $pathToBaseDir/master_log.txt
   echo "=NoGo $(date +%a) $(date +%D) $(date +%T) go marker found absent, exiting..." >> ./master_log.txt
   echo "<BR>=NoGo $(date +%a) $(date +%D) $(date +%T) go marker found absent, exiting..." >> $pathToBaseDir/"$HOSTNAME".txt
   exit 0
fi

   echo "Start me up..."

   # MESSAGE="Start of $ESSID $johnRules $1 looping."
   # SENDEMAILALERT

   echo "Check for: $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"
   echo "Check for: $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress"

   ### Check for marker file or InProgress indicator file...
   if [ ! -e $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules ] && \
      [ ! -e $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress ] ; then

      touch $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
      touch $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress

      echo "Did not find $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"
      echo "Did not find $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress"

      count=$(cat $pathToHexBaseDir/$wordListDir/$hexVal.txt | wc -l)
      # easyHexVal=$(echo -n 0x$hexVal | xxd -r)

      echo "+++$(date +%a) $(date +%D) $(date +%T) Start $crackTool on AP=$ESSID, MAC=$BSSID, using $hexVal '$easyHexVal' dir=$wordListDir, rule=$johnRules file=$FILE1 count=$count. ++++"
      echo "<BR>+++$(date +%a) $(date +%D) $(date +%T) Start $crackTool on AP=$ESSID, MAC=$BSSID, using $hexVal '$easyHexVal' dir=$wordListDir, rule=$johnRules file=$FILE1 count=$count. ++++" >> $pathToBaseDir/master_log.txt
      # echo "<BR>+++$(date +%a) $(date +%D) $(date +%T) Start $crackTool on AP=$ESSID, MAC=$BSSID, using $hexVal '$easyHexVal' dir=$wordListDir, rule=$johnRules file=$FILE1 count=$count. ++++" >> ./master_log.txt
      echo "<BR>+++$(date +%a) $(date +%D) $(date +%T) Start $crackTool on AP=$ESSID, MAC=$BSSID, using $hexVal '$easyHexVal' dir=$wordListDir, rule=$johnRules file=$FILE1 count=$count. ++++" >> $pathToBaseDir/"$HOSTNAME".txt

      RC1=91

         getSTARTDATE

         if [ $count -gt 0 ] ; then

         echo "Using $pathToHexBaseDir/$wordListDir/$hexVal.txt ..."

         case $crackTool in

             aircrack-ng) echo "Using $hexVal to create and sort-u filename $HOSTNAME"_sortu.txt""
                          john -w:$pathToHexBaseDir/$wordListDir/$hexVal.txt --rules:$johnRules -stdout | grep '^.\{8\}' | sort -u > $HOSTNAME"_sortu.txt"
                          aircrack-ng -w $HOSTNAME"_sortu.txt" -b $BSSID -l $ESSID"_key.txt" $pcapFile
                          RC1=$?
                          rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
                          rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress
                          rm $HOSTNAME"_sortu.txt"
                          ;;
                   pyrit) john -w:$pathToHexBaseDir/$wordListDir/$hexVal.txt --rules:$johnRules -stdout | grep '^.\{8\}' | pyrit -i - -b $BSSID -o $ESSID"_key.txt" -r $pcapFile --all-handshakes attack_passthrough
                          RC1=$?
                          rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
                          rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress
                          ;;
                       *) echo "=NoGo $(date +%a) $(date +%D) $(date +%T) crack tool not found, exiting..."
                          echo "<BR>=NoGo $(date +%a) $(date +%D) $(date +%T) crack tool not found, exiting..." >> $pathToBaseDir/master_log.txt
                          echo "<BR>=NoGo $(date +%a) $(date +%D) $(date +%T) crack tool not found, exiting..." >> ./master_log.txt
                          echo "<BR>=NoGo $(date +%a) $(date +%D) $(date +%T) crack tool not found, exiting..." >> $pathToBaseDir/"$HOSTNAME".txt
                          rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
                          rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress

                          exit 0;;
         esac

         fi ## if hexVal count -gt 0

         getENDDATE

         sec_old=$(date -d "$STARTDATE" +%s)
         sec_new=$(date -d "$ENDDATE" +%s)
         ELAPSEDSECONDS=$(( sec_new - sec_old ))
         # KEYSPERSECOND=$(( NUMOFKEYS / ELAPSEDSECONDS ))
         ELAPSEDMINS=$(( ELAPSEDSECONDS / 60 ))
         if (( $ELAPSEDMINS < 1 )) ; then
           # ELAPSEDMINS="less than 1"
           ELAPSEDMINS=0
         fi

      sleep 0.0050

      if [ -e $HOMEP/"$ESSID"_key.txt ] ; then
         # This is the way to check if aircrack-ng has found the key.
         # Use aircrack-ng -l $ESSID.txt switch to write to a file.
         KEY=$(cat $HOMEP/"$ESSID"_key.txt)
         MESSAGE="Please check findings '$KEY'"
         SENDEMAILALERT
         echo "=KEY- $(date +%a) $(date +%D) $(date +%T) =====Completed $hexVal cycle, found key '$KEY' end ====="
         echo "=KEY- $(date +%a) $(date +%D) $(date +%T) =====Completed $hexVal cycle, found key '$KEY' end =====" >> $pathToBaseDir/master_log.txt
         echo "=KEY- $(date +%a) $(date +%D) $(date +%T) =====Completed $hexVal cycle, found key '$KEY' end =====" >> ./master_log.txt
         echo "<BR>=KEY- $(date +%a) $(date +%D) $(date +%T) =====Completed $hexVal cycle, found key '$KEY' end =====" >> $pathToBaseDir/"$HOSTNAME".txt
         touch $HOMEP/$pathToMarkers/$hexVal"_$1"_$johnRules
         echo "#### wordListDirRules $wordListDir $johnRules" >> ./config.cfg
         rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
         rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress
         exit 0
      fi # Check for key presence

      touch $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules
      touch $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME
      # rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
      # rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress

   else ### Following else clause is executed if marker or InProgress is found...
      echo "=MRK- $(date +%a) $(date +%D) $(date +%T) ==== Completed $hexVal '$easyHexVal' Marker or InProgress."
      echo "<BR>=MRK- $(date +%a) $(date +%D) $(date +%T) ==== Completed $hexVal '$easyHexVal' Marker or InProgress." >> $pathToBaseDir/master_log.txt
      # echo "<BR>=MRK- $(date +%a) $(date +%D) $(date +%T) ==== Completed $hexVal '$easyHexVal' Marker found or InProgress, has this been attempted already?" >> ./master_log.txt
      echo "<BR>=MRK- $(date +%a) $(date +%D) $(date +%T) ==== Completed $hexVal '$easyHexVal' Marker or InProgress." >> $pathToBaseDir/"$HOSTNAME".txt

      # rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
      # rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress

      ELAPSEDSECONDS=0
      ELAPSEDMINS=0
   fi # Check for marker $pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules
      # Check for marker $HOMEP/$pathToMarkers/$hexVal_$hexDir_$johnRules_$InProgress

   echo "=$(date +%a) $(date +%D) $(date +%T) ==== Completed $hexVal '$easyHexVal' cycle in $((($ELAPSEDSECONDS/86400)%24))d $((($ELAPSEDSECONDS/3600)%24))h $(($ELAPSEDSECONDS%3600/60))m $(($ELAPSEDSECONDS%60))s dir=$wordListDir, rule=$johnRules file=$FILE1 found '$NEWCHECKFORSUCCESS', move along ====="
   echo "<BR>=$(date +%a) $(date +%D) $(date +%T) ==== Completed $hexVal '$easyHexVal' cycle in $((($ELAPSEDSECONDS/86400)%24))d $((($ELAPSEDSECONDS/3600)%24))h $(($ELAPSEDSECONDS%3600/60))m $(($ELAPSEDSECONDS%60))s dir=$wordListDir, rule=$johnRules file=$FILE1 found '$NEWCHECKFORSUCCESS', move along =====" >> $pathToBaseDir/master_log.txt
### Modded log below...
   echo "<BR>=$(date +%a) $(date +%D) $(date +%T) ==== Completed $hexVal '$easyHexVal' cycle in $((($ELAPSEDSECONDS/86400)%24))d $((($ELAPSEDSECONDS/3600)%24))h $(($ELAPSEDSECONDS%3600/60))m $(($ELAPSEDSECONDS%60))s dir=$wordListDir, rule=$johnRules file=$FILE1 found '$NEWCHECKFORSUCCESS', move along =====" >> $pathToBaseDir/"$HOSTNAME".txt

         if (( $ELAPSEDSECONDS > 0 )) ; then
            echo "<BR>=$(date +%a) $(date +%D) $(date +%T) ==== Completed $hexVal '$easyHexVal' cycle in $((($ELAPSEDSECONDS/86400)%24))d $((($ELAPSEDSECONDS/3600)%24))h $(($ELAPSEDSECONDS%3600/60))m $(($ELAPSEDSECONDS%60))s dir=$wordListDir, rule=$johnRules file=$FILE1 found '$NEWCHECKFORSUCCESS', by $HOSTNAME =====" >> ./master_log.txt
         fi

   echo " "
   sleep 0.0050

   ### Below line gets commented out since with a cluster of 3+ machines, this thing creates a hole which makes duplication possible.
   # rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$InProgress
   rm $HOMEP/$pathToMarkers/$hexVal"_"$wordListDir"_"$johnRules"_"$HOSTNAME"_"$InProgress
done # for hexVal looping
getScriptEndDate
script_sec_old=$(date -d "$scriptStartDate" +%s)
script_sec_new=$(date -d "$scriptEndDate" +%s)
scriptELAPSEDSECONDS=$(( script_sec_new - script_sec_old ))

echo "=END- $(date +%a) $(date +%D) $(date +%T) Loop '$ESSID' '$wordListDir' '$johnRules' ended in $((($scriptELAPSEDSECONDS/86400)%24))d $((($scriptELAPSEDSECONDS/3600)%24))h $(($scriptELAPSEDSECONDS%3600/60))m $(($scriptELAPSEDSECONDS%60))s by $HOSTNAME"
echo "=END- $(date +%a) $(date +%D) $(date +%T) Loop '$ESSID' '$wordListDir' '$johnRules' ended in $((($scriptELAPSEDSECONDS/86400)%24))d $((($scriptELAPSEDSECONDS/3600)%24))h $(($scriptELAPSEDSECONDS%3600/60))m $(($scriptELAPSEDSECONDS%60))s by $HOSTNAME" >> ./master_log.txt
echo "=END- $(date +%a) $(date +%D) $(date +%T) Loop '$ESSID' '$wordListDir' '$johnRules' ended in $((($scriptELAPSEDSECONDS/86400)%24))d $((($scriptELAPSEDSECONDS/3600)%24))h $(($scriptELAPSEDSECONDS%3600/60))m $(($scriptELAPSEDSECONDS%60))s by $HOSTNAME" >> ../master_log.txt
echo "=END- $(date +%a) $(date +%D) $(date +%T) Loop '$ESSID' '$wordListDir' '$johnRules' ended in $((($scriptELAPSEDSECONDS/86400)%24))d $((($scriptELAPSEDSECONDS/3600)%24))h $(($scriptELAPSEDSECONDS%3600/60))m $(($scriptELAPSEDSECONDS%60))s by $HOSTNAME" >> $pathToBaseDir/master_log.txt
echo "=END- $(date +%a) $(date +%D) $(date +%T) Loop '$ESSID' '$wordListDir' '$johnRules' ended in $((($scriptELAPSEDSECONDS/86400)%24))d $((($scriptELAPSEDSECONDS/3600)%24))h $(($scriptELAPSEDSECONDS%3600/60))m $(($scriptELAPSEDSECONDS%60))s by $HOSTNAME" >> $pathToBaseDir/"$HOSTNAME".txt
MESSAGE="End of '$ESSID' '$wordListDir' '$johnRules' looping '$(date +%R)'."
echo "#### wordListDirRules $wordListDir $johnRules" >> ./config.cfg
SENDEMAILALERT

exit 0
