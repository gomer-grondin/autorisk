#!/bin/bash
# 
#  start server
#
#

function barf {
  echo "$*"
  exit 111
}

function cluck {
  echo "$*"
}

function PGPrunning {
  RVAL=1
  if test -f "$PGPLOCK" ; then
     export PGP=`cat $PGPLOCK | awk '{print $1}'`
     export PARENT=`cat $PGPLOCK | awk '{print $2}'`
     if test -n "$PARENT" ; then 
        for p in `pgrep -P $PARENT` ; do
          if test "$p" = "$PGP" ; then RVAL=0 ; fi
        done
     fi
  fi
  test "$RVAL" = "1" && killPGP $PARENT
  return $RVAL
}

function killPGP {
  PARENT=$1
  if test -n "$PARENT" ; then $BASE/kill_offspring $PARENT ; fi
}

function SOAPrunning {
  RVAL=1
  if test -f "$SOAPLOCK" ; then
     export SOAP=`cat $SOAPLOCK | awk '{print $1}'`
     export PARENT=`cat $SOAPLOCK | awk '{print $2}'`
     if test -n "$PARENT" ; then 
        for p in `pgrep -P $PARENT` ; do
          if test "$p" = "$SOAP" ; then RVAL=0 ; fi
        done
     fi
  fi
  test "$RVAL" = "1" && killSOAP $SOAP
  return $RVAL
}

function killSOAP {
  SOAP=$1
  if test -n "$SOAP" ; then $BASE/kill_soap $SOAP ; fi
}

if test -f "$PANIC" ; then
   SOAPrunning && test -n "$SOAP" && killSOAP $SOAP
   PGPrunning && test -n "$PARENT" && killPGP $PARENT
   rm -f $SOAPLOCK $PGPLOCK
   barf "`date` panic! "
fi 

# start SOAP server
if SOAPrunning ; then
  cluck "`date` SOAP pids $PARENT and $SOAP still active"
else
  perl -I $BASE $BASE/server localhost 38087 10 >> $SOAPLOG 2>&1 &
  SOAP=$!
  echo "$SOAP $$" > $SOAPLOCK
  cluck "`date` starting soapserver .. pid is $SOAP .. parent is $$"
fi

# start PGP server
if PGPrunning ; then
  cluck "`date` PGP pids $PARENT and $PGP still active"
else
  perl -I $BASE/modules $BASE/IPCPGP.pl .01 >> $PGPLOG 2>&1 &
  PGP=$!
  echo "$PGP $$" > $PGPLOCK
  cluck "`date` starting IPCPGP .. pid is $PGP .. parent is $$"
fi

wait
