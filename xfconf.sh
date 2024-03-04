#!/bin/bash
# Author: psi-jack
# Usage:
#    xfconf.sh <command> <file>
# Improve:
#    find a list online of datatypes for the xfce schema and calculate the created datatypes that way.

thisDE=xfce4
thisDEconf=xfconf-query
thismode="${1}"
infile="${2}"

function showHelp {
   echo "Usage: $(basename "$0") <command> <file>"
   echo
   echo "Commands:"
   echo "  dump - Dump Configuration to <file>"
   echo "  load - Load Configuration from <file>"
   echo "  help - You're looking at it"
   exit 0
}

function checks {
   if [[ ! -r "${infile}" ]]
   then
      echo "File '$infile' not found."
      exit 1
   fi
   if [[ ! -x "$( which "${thisDEconf}" )" ]]
   then
      echo "Error: Cannot find ${thisDEconf}"
      exit 2
   fi
   return 0
}

function getSession {
   if test -n "${SUDO_USER}"; then
      _user="${SUDO_USER}"
   else
      _user="${USER}"
   fi

   thispid="$(pgrep -u "$_user" "${thisDE}-session(\s|$)" | sort | uniq | head -n1)"

   source <(tr '\0' '\n' < "/proc/${thispid}/environ" | grep -E "DBUS_SESSION_BUS_ADDRESS|DISPLAY")
   echo "DBUS_SESSION_BUS_ADDRESS = $DBUS_SESSION_BUS_ADDRESS"
   echo "DISPLAY = $DISPLAY"
   if [[ -z "$DBUS_SESSION_BUS_ADDRESS" || -z "$DISPLAY" ]]
   then
      echo "$0 error: Skipping ${thisDE}: Could not find current session." 1>&2
      return 1
   fi

   return 0
}

function loadConfig {
   checks || exit $?
   getSession || exit $?

   #exit 0 #FIXME
   # Assume infile exists as a file (we tested earlier)
   if [[ -n "$thispid" && -n "$DBUS_SESSION_BUS_ADDRESS" ]]
   then

      # get user of that directory
      #thisowner="$( stat -c '%U' "${infile}" )"
      #thisowneruid="$( stat -c '%u' "${infile}" )"

      # xfce custom configuration
      while read -r channel attrib value
      do
         # display output
         #printf "channel=%s\tattrib=%s\tvalue\%s\n" "${channel}" "${attrib}" "${value}"

         # provide data type. This needs to be researched before making a new .xfconf file.
         _thistype=string
         case "${attrib}" in
            *last-separator-position) _thistype=integer ;;
            *last-show-hidden|*misc-single-click) _thistype=bool ;;
         esac

         shopt -s extglob
         if [[ "$value" == "<<UNSUPPORTED>>" ]]; then
            continue
         elif [[ "$value" == "true" || "$value" == "false" ]]; then
            _thistype=bool
         elif [[ -z "$value" ]]; then
            value='""'
         elif [[ $value = @(*[0123456789]*|!([+-]|)) && $value = ?([+-])*([0123456789]) ]]; then
            _thistype=int
         elif [[ $value = @(*[0123456789]*|!([+-]|)) && $value = ?([+-])*([0123456789])?(.*([0123456789])) ]]; then
            _thistype=double
         fi

         # make change
         if [[ "$_thistype" == "string" ]]; then
            #echo ${thisDEconf} --create -t ${_thistype} -c "${channel}" -p "${attrib}" -s "${value}"
            output="$(env DISPLAY="${DISPLAY}" DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}" ${thisDEconf} --create -t ${_thistype} -c "${channel}" -p "${attrib}" -s "${value}" 2>&1)"
            if [[ "$output" == "Unable to determine the type of the value." ]]; then
               echo ${thisDEconf} --create -t ${_thistype} -c "${channel}" -p "${attrib}" -s "${value}"
            fi
         else
            #echo ${thisDEconf} --create -t ${_thistype} -c "${channel}" -p "${attrib}" -s "${value}"
            output="$(env DISPLAY="${DISPLAY}" DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}" ${thisDEconf} --create -t ${_thistype} -c "${channel}" -p "${attrib}" -s "${value}" 2>&1)"
            if [[ "$output" == "Unable to determine the type of the value." ]]; then
               echo ${thisDEconf} --create -t ${_thistype} -c "${channel}" -p "${attrib}" -s "${value}"
            fi
         fi
         #sudo su - "${thisowner}" -c "DISPLAY=${DISPLAY} DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS} ${thisDEconf} --create -t ${_thistype} -c ${channel} -p ${attrib} -s ${value}"
      done < <(grep -viE '^\s*((#|;).*)?$' "${infile}")
   fi
}

function dumpConfig {
   if [[ -z "$infile" ]]
   then
      echo "Error: Filename not provided"
      exit 1
   fi
   xfconf-query -l | sed -r -e '/Channels:/d' | while read -r line
   do
      xfconf-query -lv -c "${line}" | sed -r -e "s/^/${line} /"
   done > "$infile"
   echo "Xfce Configuration dumped to '$infile'"
}

case "${thismode,,}" in
   dump)    dumpConfig;;
   load)    loadConfig;;
   help)    showHelp;;
   *)       showHelp;;
esac
