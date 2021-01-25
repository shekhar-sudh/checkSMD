#!/bin/sh
####################################################################################
# Script Name: smdagent_check.sh                                                   #
# Script to check the SAP SMD Agent status and start if it is down                 # 
####################################################################################
#                                                                                  # 
# Version History: 1.0 by Sudhanshu Shekhar on 08/14/2015                          #
# For Support Contact : sudhanshu.shekhar@company.com, 							   #
# Usage Example smdagent_check.sh SID 97                                           #
####################################################################################

# Setting Variables and CMD arguments 
MY_NAME=$0
sap_sid=`echo $1 | tr "[a-z]" "[A-Z]"`
smdagent_sysno=$2
Logfile=/home/smdadm/smdagent_check.log

MAILLIST=sudhanshu.shekhar@company.com


# Export environment
. /home/`whoami`/.sapenv_`hostname`.sh
. /home/`whoami`/.j2eeenv_`hostname`.sh

#Remove old logs first
rm ${Logfile}

# Check input values, send mail and exit if sap_sid and smdagent_sysno are not setup correctly in crontab
if [ "$#" -lt 2 ] ; then
  echo "Usage:   $MY_NAME <smdagent_sysno>" >> ${Logfile}
  echo "Example: $MY_NAME SID 97" >> ${Logfile}
  mailx -s "smdagent_check.sh script on `hostname` is not setup properly, please check the usage and set up" ${MAILLIST} < ${Logfile}
  exit 
fi
 
# Checking if SAP is up or not, script proceeds only if SAP is up 
ig_sapSID_process=$( ps -ef |grep ig.sap${sap_sid} | wc -l)
dw_sapSID_process=$( ps -ef |grep dw.sap${sap_sid} | wc -l)
jc_sapSID_process=$( ps -ef |grep jc.sap${sap_sid} | wc -l)
 
if  [ ${dw_sapSID_process} -ge 5 ]  || [  ${jc_sapSID_process} -ge 2 ] && [ ${ig_sapSID_process} -ge 2 ]
then
       echo "SAP is up .. so I am checking the smdagent status " >> ${Logfile}
       
       echo >> ${Logfile}
	   echo "Count the current number of smdagent processes" >> ${Logfile}
           PROCESS_jc=$( ps -ef | grep "SMD_SMDA${smdagent_sysno}_`hostname`" | grep "jc.sapSMD_SMDA${smdagent_sysno}" | wc -l)
	   PROCESS_jstart=$( ps -ef | grep "SMD_SMDA${smdagent_sysno}_`hostname`" | grep "nodeName=smdagent" | wc -l)
       echo >> ${Logfile}
	   echo "Count of existing smdagent jc process = ${PROCESS_jc}, jstart process = ${PROCESS_jstart}" >> ${Logfile}
	   echo >> ${Logfile}
	   
	   
	   echo "Collect Status from the SMD agent connector listener" >> ${Logfile}
	   SMD_lsnr_status=tail -1 /usr/sap/SMD/SMDA{smdagent_sysno}/SMDAgent/log/smd.*.connector.listener.log | awk '{ print $(NF) }'
	   echo "SMD agent connector listener status is ${SMD_lsnr_status}"
	   
	   echo >> ${Logfile}
	   echo " Set the SMD agent connector listener status code" >> ${Logfile}
	   if [ ${SMD_lsnr_status} == CONNECTED ]
	   then
	   SMD_lsnr_status_code=1
	   else
	   SMD_lsnr_status_code=0
	   fi
	   echo "SMD agent connector listener status code is ${SMD_lsnr_status_code}, note - code 1 is good, code 0 is bad" >> ${Logfile}
	   
       #If both the process counts are equal to 1 and SMD listener status code is 1 (good), then quit, otherwise restart the dead smdagent
       if [ ${PROCESS_jc} -eq 1 ] && [ ${PROCESS_jstart} -eq 1 ] && [ ${SMD_lsnr_status_code} -eq 1]
       then
                echo >> ${Logfile}
                echo "SAP SMD agent is already running" >> ${Logfile}
		echo >> ${Logfile}
		echo " SMD agent processes running currently are as follows" >> ${Logfile}
		echo >> ${Logfile}
		ps -ef | grep "SMD_SMDA${smdagent_sysno}_`hostname`" | grep "jc.sapSMD_SMDA${smdagent_sysno}" >> ${Logfile}
		ps -ef | grep "SMD_SMDA${smdagent_sysno}_`hostname`" | grep "nodeName=smdagent" >> ${Logfile}
		exit 
       else 
                echo >> ${Logfile}
                echo "Stop the residual smdagent processes if any" >> ${Logfile}
		stopsap_command=`which stopsap`
		echo >> ${Logfile}
		$stopsap_command SMDA$smdagent_sysno >> ${Logfile}
		sapcontrol_command=`which sapcontrol`
		echo >> ${Logfile}
		$sapcontrol_command -nr $smdagent_sysno -function StopService >> ${Logfile}
                cleanipc_command=`which cleanipc`
		echo >> ${Logfile}
                $cleanipc_command $smdagent_sysno remove >> ${Logfile}
		echo >> ${Logfile}
		echo "Start smdagent processes now" >> ${Logfile}
                startsap_command=`which startsap`
		echo >> ${Logfile}
                $startsap_command SMDA$smdagent_sysno >> ${Logfile}
        	echo >> ${Logfile}			
		echo "SMD agents running currently are as follows" >> ${Logfile}
		echo >> ${Logfile}
		ps -ef | grep "SMD_SMDA${smdagent_sysno}_`hostname`" >> ${Logfile}
		mailx -s "smdagent on `hostname` was found dead, it has been started again" ${MAILLIST} < ${Logfile}
                exit 
       fi
       exit
else
       echo "SAP is not up... so I am exiting..." >> ${Logfile}
       exit
fi
