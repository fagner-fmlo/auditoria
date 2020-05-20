#!/bin/bash
# Updated Mar 08 2020

function InitializeStats
{
   SerialNumber="Unknown";
   LastATAError=0;
   ATAError=0;
   CommandTimeout=0;
   Reallocated=0;
   CurrentPending=0;
   OfflineUncorrectable=0;
   PowerOnHours=0;
   Status="Unknown";
   IsSAS="No";
}

Month=`date +%b`
Day=`date +%e`
Date="$Month $Day"
echo "$Date"
echo "Drive Health History:"
if [ -d /var/log/axond ]; then
   for i in `ls -alh /var/log/axond | grep "$Date" | grep smartctl | awk '{print $9}'`
   do
     echo -e "`head -n2 /var/log/axond/"$i"; grep -v SMART /var/log/axond/"$i" | sort -k4 -k5 -k6 -k7 -n -u | tail`\n";
   done
fi



function DisplayStats
{
   if [[ $IsRAID == "Yes" && -n $Status && $ShowStatus == "Yes" ]]; then
      echo "Drive Status: $Status";
   elif [[ $IsRAID == "Yes" && $ShowStatus == "Yes" ]]; then
      echo "Drive Status: Unknown";
   fi
   if [[ $SerialNumber != "Unknown" ]]; then
      echo "Serial Number: $SerialNumber";
   fi
   if [[ $Reallocated != 0 && -n $Reallocated ]]; then
      echo "Reallocated Sectors - $Reallocated";
   fi
   if [[ $CurrentPending != 0 && -n $CurrentPending ]]; then
      echo "Current Pending Sectors - $CurrentPending";
   fi
   if [[ $OfflineUncorrectable != 0 && -n $OfflineUncorrectable ]]; then
      echo "Offline Uncorrectables - $OfflineUncorrectable";
   fi
   if [[ -z $Reallocated && -z $CurrentPending && -z $OfflineUncorrectable ]]; then
      echo "Unable to retrieve SMART stats for this drive.";
   fi
   if [[ -n $ATAError && $ATAError != 0 ]]; then
      echo "ATA Errors - $ATAError";
      Difference=$(($PowerOnHours - $LastATAError));
      Days=$(($Difference /24));
      if [[ $Days != 0 && $Days != 1 ]]; then
         echo "Last ATA error occurred $Difference hours ($Days days) ago.";
      elif [[ $Days == 1 ]]; then
         echo "Last ATA error occurred $Difference hours ($Days day) ago.";
      else
         echo "Last ATA error occurred $Difference hours ago.";
      fi
   fi
   if [[ ( $Reallocated == 0 ) && ( $CurrentPending == 0 || -z $CurrentPending ) && ( $OfflineUncorrectable == 0 || -z $OfflineUncorrectable ) && ( -z $ATAError || $ATAError == 0 ) && $IsSAS == "No" ]]; then
      echo "Drive is healthy.";
   fi
   if [[ $CommandTimeout != 0 && -n $CommandTimeout ]]; then
      echo "Command Timeout (SATA Cable) - $CommandTimeout";
   fi
   if [[ -n $PowerOnHours && $PowerOnHours != 0 ]]; then
      if [[ $PowerOnHours -gt 24 ]]; then
         Days=$((($PowerOnHours /24) % 365))
         if [[ $PowerOnHours -gt 8760 ]]; then
            Years=$(($PowerOnHours /8760));
            if [[ $Years == 1 ]]; then
               echo "Active: $Years year and $Days days";
            else
               echo "Active: $Years years and $Days days";
            fi
         else
            echo "Active: $Days days";
         fi
      else
         echo "Active: $PowerOnHours hours";
      fi
   fi
   echo;
}

function Check3wareStatus
{
   Controller=`/usr/local/bin/3ware show | grep c | head -n 1 | awk '{print $1}'`;
   CardStatus=`/usr/local/bin/3ware /$Controller show | grep -m 1 u0 | awk '{print $3}'`;
   if [[ $CardStatus != "REBUILDING" && $CardStatus != "VERIFYING" ]]; then
      echo "The RAID status is: $CardStatus"; echo;
   elif [[ $CardStatus == "VERIFYING" ]]; then
      echo -n "The RAID status is: $CardStatus - "; /usr/local/bin/3ware /$Controller show | grep -m 1 u0 | awk '{print $5}'; echo; echo;
   else
      echo -n "The RAID status is: $CardStatus - "; /usr/local/bin/3ware /$Controller show | grep -m 1 u0 | awk '{print $4}'; echo; echo;
   fi
}

function CheckAdaptecStatus
{
   CardStatus=`/usr/local/bin/arcconf getconfig 1 | grep -m 1 'Status of logical device' | awk '{print $6}'`;
   CurrentOperation=`/usr/local/bin/arcconf getstatus 1 | grep 'Current operation' | awk '{print $4}'`;
   if [[ $CardStatus == "Degraded" && -n $CurrentOperation && "`/usr/local/bin/arcconf getstatus 1 | grep Current | awk '{print $4}'`" != "None" ]]; then
      Status=`/usr/local/bin/arcconf getstatus 1 | grep 'Percentage complete' | awk '{print $4}'`;
      echo "The RAID status is: $CurrentOperation - $Status%"; echo;
   else
      echo "The RAID status is: $CardStatus"; echo;
   fi
}

IsRAID="No"; #Used to determine the server's setup
ShowStatus="Yes";

#Check if server is a VPS
if ! which smartctl &>/dev/null; then echo "No RAID found"; exit 1; fi

#Check if the RAID is 3ware and the drives are SAS
if [[ -n "`/usr/sbin/smartctl -ad 3ware,0 /dev/twa0 -T permissive | grep 'Input/output error'`" || "`/usr/sbin/smartctl -ad 3ware,0 /dev/twe0 -T permissive | grep 'Input/output error'`" ]]; then
   IsRAID="Yes";
   echo; echo "The server has a 3ware RAID";
   Check3wareStatus
   NumDrives=`/usr/local/bin/3ware show | grep $Controller | awk '{print $4}'`;
   for i in $(eval echo "{0..$((NumDrives-1))}");
   do
      echo -n p$i:; echo;
      IFS=$'\n';
      SMART=`/usr/local/bin/3ware /$Controller/p$i show all | egrep -i 'serial|reallocated|power|status'`;
      if [[ -n $SMART ]]; then
         set $SMART
         for j in {1..8};
         do
            if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated" ]]; then
               Reallocated=`echo ${!j} | awk '{print $5}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Power" ]]; then
               PowerOnHours=`echo ${!j} | awk '{print $6}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Serial" ]]; then
               SerialNumber=`echo ${!j} | awk '{print $4}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Status" ]]; then
               Status=`echo ${!j} | awk '{print $4}'`;
            fi
         done;
      fi
      echo "Drive Status: $Status";
      echo "Serial Number: $SerialNumber";
      if [[ $Reallocated != 0 && -n $Reallocated ]]; then
         echo "Reallocated Sectors - $Reallocated";
      else
         echo "Drive is healthy.";
      fi
      if [[ -n $PowerOnHours && $PowerOnHours != 0 ]]; then
         if [[ $PowerOnHours -gt 24 ]]; then
            Days=$((($PowerOnHours /24) % 365))
            if [[ $PowerOnHours -gt 8760 ]]; then
               Years=$(($PowerOnHours /8760));
               if [[ $Years == 1 ]]; then
                  echo "Active: $Years year and $Days days";
               else
                  echo "Active: $Years years and $Days days";
               fi
            else
               echo "Active: $Days days";
            fi
         else
            echo "Active: $PowerOnHours hours";
         fi
      fi
      echo;
   done;
#Check if the RAID is 3ware and the drives aren't SAS
elif [[ -x /usr/local/bin/3ware && -z "`/usr/local/bin/3ware show | grep 'No controller found.'`" ]]; then
   IsRAID="Yes";
   echo; echo "The server has a 3ware RAID";
#Case twe0
   if [[ -n "`/usr/sbin/smartctl -ad 3ware,0 /dev/twe0 | grep -i -e Reallocated_Sector_Ct -e Reallocated_Event_Count`" ]]; then
      Check3wareStatus
      NumDrives=`/usr/local/bin/3ware show | grep $Controller | awk '{print $4}'`;
      for i in $(eval echo "{0..$((NumDrives-1))}");
      do
         echo -n p$i:; echo;
         InitializeStats
         Status=`/usr/local/bin/3ware /$Controller show | grep p$i | awk '{print $2}'`;
         IFS=$'\n';
         SMART=`/usr/sbin/smartctl -ad 3ware,$i /dev/twe0 | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
         if [[ -n $SMART ]]; then
            set $SMART
            for j in {1..8};
            do
                  if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
                     Reallocated=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
                     Reallocated=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
                     CurrentPending=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
                     OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
                     CommandTimeout=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
                     CommandTimeout=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
                     PowerOnHours=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
                     ATAError=`echo ${!j} | awk '{print $4}'`;
                  elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
                     LastATAError=`echo ${!j} | awk '{print $8}'`;
                  elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
                     SerialNumber=`echo ${!j} | awk '{print $3}'`;
                  fi
            done;
         fi
         DisplayStats
      done;
#Case twa0
   elif [[ -n "`/usr/sbin/smartctl -ad 3ware,0 /dev/twa0 | grep -i -e Reallocated_Sector_Ct -e Reallocated_Event_Count | awk '{print $1}'`" ]]; then
      Check3wareStatus
      NumDrives=`/usr/local/bin/3ware show | grep $Controller | awk '{print $4}'`;
      for i in $(eval echo "{0..$((NumDrives-1))}");
      do
         echo -n p$i:; echo;
         InitializeStats
         Status=`/usr/local/bin/3ware /$Controller show | grep p$i | awk '{print $2}'`;
         IFS=$'\n';
         SMART=`/usr/sbin/smartctl -ad 3ware,$i /dev/twa0 | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
         if [[ -n $SMART ]]; then
            set $SMART
            for j in {1..8};
            do
                  if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
                     Reallocated=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
                     Reallocated=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
                     CurrentPending=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
                     OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
                     CommandTimeout=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
                     CommandTimeout=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
                     PowerOnHours=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
                     ATAError=`echo ${!j} | awk '{print $4}'`;
                  elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
                     LastATAError=`echo ${!j} | awk '{print $8}'`;
                  elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
                     SerialNumber=`echo ${!j} | awk '{print $3}'`;
                  fi
            done;
         fi
         DisplayStats
      done;
   fi
#Check if the RAID is Adaptec
elif [[ -x /usr/local/bin/arcconf && "`/usr/local/bin/arcconf getconfig 1 | grep "Controllers found:" | awk '{print $3}'`" == "1" ]]; then
   IsRAID="Yes";
   echo; echo "The server has an Adaptec RAID";
   #Check if the drives are SAS
   if [[ -n "`/usr/sbin/smartctl -ad scsi /dev/sg2 | grep -i 'number of hours powered up'`" ]]; then
      echo; echo "No relevant health information for Adaptec SAS drives."; echo;
      #Check if the drives start at sg2
      if [[ -z "`/usr/sbin/smartctl -ad scsi /dev/sg1 | grep -i 'Current Drive Temperature'`" && -z "`/usr/sbin/smartctl -ad scsi /dev/sg1 | grep -i 'empty IDENTIFY data'`" ]]; then
         CheckAdaptecStatus
         if [[ "`/usr/local/bin/arcconf getconfig 1 ld | grep -m 1 Segment | awk '{print $5}'`" != ":" ]]; then
            NumDrives=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $5}' | sort | tail -n 1 | cut -c 4`;
         else
            NumDrives=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $7}' | sort | tail -n 1 | cut -c 4`;
         fi
         if [[ "`/usr/local/bin/arcconf getconfig 1 ld | grep -m 1 Segment | awk '{print $5}'`" != ":" ]]; then
            Segment=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $5}' | sort | head -n 1 | cut -c 4`;
         else
            Segment=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $7}' | sort | head -n 1 | cut -c 4`;
         fi
         for i in $(eval echo "{2..$((NumDrives+2))}");
         do
            echo -n p$[i-2]:; echo;
            InitializeStats
            IsSAS="Yes"
            if [[ "`/usr/local/bin/arcconf getconfig 1 | grep "(0,$Segment)" | awk '{print $1}' | head -n 1`" != "Group" ]]; then
               Status=`/usr/local/bin/arcconf getconfig 1 | grep -m 1 "(0,$Segment)" | awk '{print $4}'`;
            else
               Status=`/usr/local/bin/arcconf getconfig 1 | grep "(0,$Segment)" | awk '{print $6}'`;
            fi
            SerialNumber=`/usr/sbin/smartctl -ad scsi /dev/sg$i | grep Serial | awk '{print $3}'`;
            DisplayStats
            let Segment++

         done;
      elif [[ -n "`/usr/sbin/smartctl -ad scsi /dev/sg1 | grep -i 'Current Drive Temperature'`" && -z "`/usr/sbin/smartctl -ad scsi /dev/sg1 | grep -i 'empty IDENTIFY data'`" ]]; then
         CheckAdaptecStatus
         if [[ "`/usr/local/bin/arcconf getconfig 1 ld | grep -m 1 Segment | awk '{print $5}'`" != ":" ]]; then
            NumDrives=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $5}' | sort | tail -n 1 | cut -c 4`;
         else
            NumDrives=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $7}' | sort | tail -n 1 | cut -c 4`;
         fi
         if [[ "`/usr/local/bin/arcconf getconfig 1 ld | grep -m 1 Segment | awk '{print $5}'`" != ":" ]]; then
            Segment=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $5}' | sort | head -n 1 | cut -c 4`;
         else
            Segment=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $7}' | sort | head -n 1 | cut -c 4`;
         fi
         for i in $(eval echo "{1..$((NumDrives+1))}");
         do
            echo -n p$[i-1]:; echo;
            InitializeStats
            IsSAS="Yes"
            if [[ "`/usr/local/bin/arcconf getconfig 1 | grep "(0,$Segment)" | awk '{print $1}' | head -n 1`" != "Group" ]]; then
               Status=`/usr/local/bin/arcconf getconfig 1 | grep -m 1 "(0,$Segment)" | awk '{print $4}'`;
            else
               Status=`/usr/local/bin/arcconf getconfig 1 | grep "(0,$Segment)" | awk '{print $6}'`;
            fi
            SerialNumber=`/usr/sbin/smartctl -ad scsi /dev/sg$i | grep Serial | awk '{print $3}'`;
            DisplayStats
            let Segment++
         done;
      fi
   IsRAID="Yes";
   #Check if the drives start at sg2 (by checking if they don't start at sg1)
   else
    #Check to see where the drives start
    if [[ `/usr/sbin/smartctl --all /dev/sg1 -d sat | grep -i "Device Read Identity Failed"` ]]; then
      #Start point is 2 since no data can be derived from sg1
      StartPoint=2
    else
      #Start point is 1 since data can be derived from sg1
      StartPoint=1
    fi
      CheckAdaptecStatus
      if [[ "`/usr/local/bin/arcconf getconfig 1 ld | grep -m 1 Segment | awk '{print $5}'`" != ":" ]]; then
         NumDrives=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $5}' | sort | tail -n 1 | cut -c 4`;
      else
         NumDrives=`/usr/local/bin/arcconf getconfig 1 ld | grep Segment | awk '{print $7}' | sort | tail -n 1 | cut -c 4`;
      fi
      for i in $(eval echo "{0..$NumDrives}");
      do
         echo -n p$i:; echo;
         InitializeStats
         IFS=$'\n';
         SMART=`/usr/sbin/smartctl -ad sat /dev/sg$StartPoint | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
         if [[ "`/usr/local/bin/arcconf getconfig 1 | grep "(0,$i)" | awk '{print $1}' | head -n 1`" != "Group" ]]; then
            Status=`/usr/local/bin/arcconf getconfig 1 | grep -m 1 "(0,$i)" | awk '{print $4}'`;
         else
            Status=`/usr/local/bin/arcconf getconfig 1 | grep "(0,$i)" | awk '{print $6}'`;
         fi
         if [[ -n $SMART ]]; then
            set $SMART
            for j in {1..8};
            do
                  if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
                     Reallocated=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
                     Reallocated=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
                     CurrentPending=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
                     OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
                     CommandTimeout=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
                     CommandTimeout=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
                     PowerOnHours=`echo ${!j} | awk '{print $10}'`;
                  elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
                     ATAError=`echo ${!j} | awk '{print $4}'`;
                  elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
                     LastATAError=`echo ${!j} | awk '{print $8}'`;
                  elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
                     SerialNumber=`echo ${!j} | awk '{print $3}'`;
                  fi
            done;
         fi
         DisplayStats
      ((StartPoint++))
      done;
   fi
#Check for MegaRAID card
elif [[ -x /usr/local/bin/megacli && -n `/usr/local/bin/megacli -AdpAllInfo -aAll | grep 'Product Name'` ]]; then
   echo; echo "The server has a MegaRAID card";
   IsRAID="Yes";
   Drive_Num=0;
   CardStatus=`/usr/local/bin/megacli -LDInfo -Lall -aALL | grep -m 1 State | awk '{print $3}'`;
   echo "The RAID status is: $CardStatus"; echo;
   if [[ -n `df -h --type ext2 --type ext3 --type ext4 --type xfs --type zfs --type btrfs --type ntfs --type fat32 | grep -i megaraid` ]]; then
      Partition=`df -h --type ext2 --type ext3 --type ext4 --type xfs --type zfs --type btrfs --type ntfs --type fat32 | grep -m 1 -i megaraid | awk '{print $1}' | cut -c 1-8`;
   else
      Partition=`df -h --type ext2 --type ext3 --type ext4 --type xfs --type zfs --type btrfs --type ntfs --type fat32 | head -n 2 | tail -n 1 | awk '{print $1}'`;
   fi

   for i in $(/usr/local/bin/megacli PDList -aALL | grep 'Device Id' | awk '{print $3}');
   do
      echo "p${Drive_Num}:"
      if [[ -n "`/usr/sbin/smartctl -ad megaraid,$i $Partition | grep 'SAS'`" ]]; then
         echo "No relevant health information for MegaRAID SAS drives."; echo;
         let Drive_Num++;
      else
         InitializeStats
         Status=`/usr/local/bin/megacli PDList -aALL | grep "Device Id: $i" -A 13 | grep "Firmware state" | awk '{print $3,$4,$5}'`;
         IFS=$'\n';
         # This by default will search via /dev/sda4, which works when the drives are on sg0, but fails when the drives are on sg1
         SMART=`/usr/sbin/smartctl -ad sat+megaraid,$i $Partition | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
         if [[ -z "$SMART" ]]; then
            SMART=`/usr/sbin/smartctl -ad sat+megaraid,$i /dev/sg1 | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
         fi
         
         if [[ -n $SMART ]]; then
            set $SMART
            for j in {1..8};
            do
               if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
                  Reallocated=`echo ${!j} | awk '{print $10}'`;
               elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
                  Reallocated=`echo ${!j} | awk '{print $10}'`;
               elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
                  CurrentPending=`echo ${!j} | awk '{print $10}'`;
               elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
                  OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
               elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
                  CommandTimeout=`echo ${!j} | awk '{print $10}'`;
               elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
                  CommandTimeout=`echo ${!j} | awk '{print $10}'`;
               elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
                  PowerOnHours=`echo ${!j} | awk '{print $10}'`;
               elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
                  ATAError=`echo ${!j} | awk '{print $4}'`;
               elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
                  LastATAError=`echo ${!j} | awk '{print $8}'`;
               elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
                  SerialNumber=`echo ${!j} | awk '{print $3}'`;
               fi
            done;
         fi
         DisplayStats
         let Drive_Num++;
      fi
   done
fi

#Non-RAID drives
ShowStatus="No"
#Primary IDE drive
if [[ -n "`df | grep hda1 | awk '{print $6}'`" || -n "`/usr/sbin/smartctl -a /dev/hda | grep -i reallocated`" ]]; then
   if [[ "`df | grep hda1 | awk '{print $6}'`" == "/boot" && $IsRAID == "No" ]]; then
      echo; echo "hda:";
      InitializeStats
      IFS=$'\n';
      SMART=`/usr/sbin/smartctl -ad ata /dev/hda | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
      if [[ -n $SMART ]]; then
         set $SMART
         for j in {1..8};
         do
            if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
               CurrentPending=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
               OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
               CommandTimeout=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
               CommandTimeout=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
               PowerOnHours=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
               ATAError=`echo ${!j} | awk '{print $4}'`;
            elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
               LastATAError=`echo ${!j} | awk '{print $8}'`;
            elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
               SerialNumber=`echo ${!j} | awk '{print $3}'`;
            fi
         done;
      fi
      DisplayStats
      echo;
   elif [[ "`df | grep hda1 | awk '{print $6}'`" == "/backup" ]]; then
      echo 'hda (backup):';
      InitializeStats
      IFS=$'\n';
      SMART=`/usr/sbin/smartctl -ad ata /dev/hda | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
      if [[ -n $SMART ]]; then
         set $SMART
         for j in {1..8};
         do
            if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
               CurrentPending=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
               OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
               CommandTimeout=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
               CommandTimeout=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
               PowerOnHours=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
               ATAError=`echo ${!j} | awk '{print $4}'`;
            elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
               LastATAError=`echo ${!j} | awk '{print $8}'`;
            elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
               SerialNumber=`echo ${!j} | awk '{print $3}'`;
            fi
         done;
      fi
      DisplayStats
      echo;
   fi
fi
#Primary SATA drive
if [[ -n "`df | grep sda1 | awk '{print $6}'`" || -n "`/usr/sbin/smartctl -a /dev/sda | grep -i reallocated | head -n 1`" ]]; then
   if [[ "`df | grep sda1 | awk '{print $6}'`" != "/backup" && $IsRAID == "No" ]]; then
      echo; echo "sda:";
      InitializeStats
      IFS=$'\n';
      SMART=`/usr/sbin/smartctl -ad ata /dev/sda | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
      if [[ -n $SMART ]]; then
         set $SMART
         for j in {1..8};
         do
            if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
               CurrentPending=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
               OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
               CommandTimeout=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
               CommandTimeout=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
               PowerOnHours=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
               ATAError=`echo ${!j} | awk '{print $4}'`;
            elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
               LastATAError=`echo ${!j} | awk '{print $8}'`;
            elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
               SerialNumber=`echo ${!j} | awk '{print $3}'`;
            fi
         done;
      fi
      DisplayStats
      echo;
   elif [[ "`df | grep sda1 | awk '{print $6}'`" == "/backup" ]]; then
      echo "sda (backup):";
      InitializeStats
      IFS=$'\n';
      SMART=`/usr/sbin/smartctl -ad ata /dev/sda | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
      if [[ -n $SMART ]]; then
         set $SMART
         for j in {1..8};
         do
            if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
               CurrentPending=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
               OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
               CommandTimeout=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
               CommandTimeout=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
               PowerOnHours=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
               ATAError=`echo ${!j} | awk '{print $4}'`;
            elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
               LastATAError=`echo ${!j} | awk '{print $8}'`;
            elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
               SerialNumber=`echo ${!j} | awk '{print $3}'`;
            fi
         done;
      fi
      DisplayStats
      echo;
   fi
fi
#Backup IDE drive (hdc)
if [[ -n "`/usr/sbin/smartctl -a -d ata /dev/hdc | grep -i Reallocated_Sector_Ct`" ]]; then
   echo "hdc:";
   InitializeStats
   IFS=$'\n';
   SMART=`/usr/sbin/smartctl -ad ata /dev/hdc | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
   if [[ -n $SMART ]]; then
      set $SMART
      for j in {1..8};
      do
         if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
            Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
            CurrentPending=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
            OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
            CommandTimeout=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
            CommandTimeout=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
            PowerOnHours=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
            ATAError=`echo ${!j} | awk '{print $4}'`;
         elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
            LastATAError=`echo ${!j} | awk '{print $8}'`;
         elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
            SerialNumber=`echo ${!j} | awk '{print $3}'`;
         fi
      done;
   fi
   DisplayStats
fi
#Backup SATA drive (sdb)
if [[ -n "`/usr/sbin/smartctl -a -d ata /dev/sdb | grep -i Reallocated_Sector_Ct`" ]]; then
   echo "sdb:";
   InitializeStats
   IFS=$'\n';
   SMART=`/usr/sbin/smartctl -ad ata /dev/sdb | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
   if [[ -n $SMART ]]; then
      set $SMART
      for j in {1..8};
      do
         if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
            Reallocated=`echo ${!j} | awk '{print $10}'`;
            elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
               Reallocated=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
            CurrentPending=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
            OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
            CommandTimeout=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
            CommandTimeout=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
            PowerOnHours=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
            ATAError=`echo ${!j} | awk '{print $4}'`;
         elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
            LastATAError=`echo ${!j} | awk '{print $8}'`;
         elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
            SerialNumber=`echo ${!j} | awk '{print $3}'`;
         fi
      done;
   fi
   DisplayStats
fi
#Backup SATA drive (sdc)
if [[ -n "`/usr/sbin/smartctl -a -d ata /dev/sdc | grep -i Reallocated_Sector_Ct`" ]]; then
   echo "sdc:";
   InitializeStats
   IFS=$'\n';
   SMART=`/usr/sbin/smartctl -ad ata /dev/sdc | egrep -i 'serial|reallocated_sector|reallocated_event|command_timeout|current_pending|offline_uncorrect|power_on|ATA Error|188 Unknown_Attribute|occurred at disk'`;
   if [[ -n $SMART ]]; then
      set $SMART
      for j in {1..8};
      do
         if [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Sector_Ct" ]]; then
            Reallocated=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Reallocated_Event_Count" ]]; then
            Reallocated=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Current_Pending_Sector" ]]; then
            CurrentPending=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Offline_Uncorrectable" ]]; then
            OfflineUncorrectable=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Command_Timeout" ]]; then
            CommandTimeout=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Unknown_Attribute" ]]; then
            CommandTimeout=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $2}'` == "Power_On_Hours" ]]; then
            PowerOnHours=`echo ${!j} | awk '{print $10}'`;
         elif [[ `echo ${!j} | awk '{print $3}'` == "Count:" ]]; then
            ATAError=`echo ${!j} | awk '{print $4}'`;
         elif [[ `echo ${!j} | awk '{print $3}'` == "occurred" && `echo ${!j} | awk '{print $8}'` > $LastATAError ]]; then
            LastATAError=`echo ${!j} | awk '{print $8}'`;
         elif [[ `echo ${!j} | awk '{print $1}'` == "Serial" ]]; then
            SerialNumber=`echo ${!j} | awk '{print $3}'`;
         fi
      done;
   fi
   DisplayStats
fi

[ -f ./MegaSAS.log ] && rm -f ./MegaSAS.log;
