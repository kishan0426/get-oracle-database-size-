
#!/bin/bash

# Oracle Database Size Report - Standalone Server

ORATAB="/etc/oratab"
REPORT="oracle_db_size_$(date +%Y%m%d_%H%M%S).csv"
LOG="oracle_db_size_$(date +%Y%m%d_%H%M%S).log"

echo "SID,DB_NAME,STATUS,SIZE_GB" > "$REPORT"

while IFS=: read -r SID OHOME FLAG
do
    # Skip comments and blank lines
    [[ -z "$SID" || "$SID" =~ ^# ]] && continue
    [[ -z "$OHOME" || ! -x "$OHOME/bin/sqlplus" ]] && continue

    echo "Processing SID: $SID"

    export ORACLE_SID="$SID"
    export ORACLE_HOME="$OHOME"
    export PATH="$ORACLE_HOME/bin:/usr/bin:/bin"

    RESULT=$("$ORACLE_HOME/bin/sqlplus" -L -s "/ as sysdba" 2>&1 <<'SQL'
WHENEVER OSERROR EXIT 9
WHENEVER SQLERROR EXIT SQL.SQLCODE

SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET VERIFY OFF
SET ECHO OFF
SET LINESIZE 200
SET TRIMSPOOL ON

SELECT
    d.name || ',' ||
    i.status || ',' ||
    TO_CHAR(ROUND(NVL(SUM(f.bytes),0)/1024/1024/1024,2))
FROM
    v$database d,
    v$instance i,
    dba_data_files f
GROUP BY
    d.name, i.status;

EXIT;
SQL
)

    RC=$?

    if [ "$RC" -eq 0 ] && [[ "$RESULT" =~ ^[^,]+,[^,]+,[0-9] ]]; then
        echo "$SID,$RESULT" >> "$REPORT"
        echo "SUCCESS: $SID - $RESULT GB"
    else
        echo "FAILED: $SID"
        echo "$RESULT" | tee -a "$LOG"
        echo "$SID,CONNECTION_FAILED,UNKNOWN,0" >> "$REPORT"
    fi

done < "$ORATAB"

echo ""
echo "=================================="
echo "Oracle Database Size Report"
echo "=================================="
echo "CSV Report : $REPORT"
echo "Error Log  : $LOG"
