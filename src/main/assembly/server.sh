#!/usr/bin/env bash

# ====================== 配置区 ==========================

APP_NAME="demo"
APP_DIR=$(pwd)
TMP_DIR="$APP_DIR/tmp"
CONF_DIR="$APP_DIR/conf"
LIB_DIR="$APP_DIR/../lib"
LOG_FILE="$APP_DIR/error.log"

# 预初始化可用的 JAR 文件名（用于显示），若不存在则保持为空
JAR_FILE=$(ls "$APP_DIR"/*.jar 2>/dev/null | head -n 1)

# JVM 参数

JAVA_OPTS="-Dname=$APP_NAME -Xmx4g -XX:+UseG1GC -XX:+UseStringDeduplication
-XX:MaxGCPauseMillis=200 -Xverify:none -Duser.timezone=GMT+08 -Djava.io.tmpdir=$TMP_DIR
-Dloader.path=$LIB_DIR"

# Spring Boot 应用参数

SPRING_OPTS="--spring.config.location=$CONF_DIR/"

# DEBUG 配置

if [ "$JAVA_DEBUG" = "true" ]; then
DEBUG_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
JAVA_OPTS="$JAVA_OPTS $DEBUG_OPTS"
echo "Debug mode enabled: remote port 5005"
fi

# 额外参数

params="$@"

# ====================== 辅助函数 =======================

mkdir_tmp() {
if [ ! -d "$TMP_DIR" ]; then
mkdir -p "$TMP_DIR"
fi
}

get_jar() {
JAR_FILE=$(ls "$APP_DIR"/*.jar 2>/dev/null | head -n 1)
if [ -z "$JAR_FILE" ]; then
echo "ERROR: No jar file found in $APP_DIR"
exit 1
fi
echo "$JAR_FILE"
}

psid=0
checkpid() {
psid=0
for pid in $(jps | awk '{print $1}'); do
if [ -d "/proc/$pid" ]; then
CUR_DIR=$(pwdx $pid 2>/dev/null | awk '{print $2}')
if [ "$CUR_DIR" = "$APP_DIR" ]; then
psid=$pid
break
fi
fi
done
}

# ====================== 主函数 ==========================

start() {
    checkpid
    if [ $psid -ne 0 ]; then
        echo "================================"
        echo "warn: ${JAR_FILE:-$APP_NAME} already started! (pid=$psid)"
        echo "================================"
    else
        mkdir_tmp
        JAR_FILE=$(get_jar)
        echo -n "Starting ${JAR_FILE:-$APP_NAME} ..."
        nohup java $JAVA_OPTS -jar "$JAR_FILE" $SPRING_OPTS $params >"$APP_DIR/nohup.out" 2>"$LOG_FILE" &
        sleep 1
        checkpid
        if [ $psid -ne 0 ]; then
            echo "(pid=$psid) [OK]"
else
echo "[Failed]"
fi
fi
}

stop() {
    checkpid
    if [ $psid -ne 0 ]; then
        kill -9 $psid
        if [ $? -eq 0 ]; then
            num=0
            spins='|/-\'
            while [ $psid -ne 0 ]; do
                index=$(( num % 4 ))
                spin=$(echo "$spins" | cut -c $((index + 1)))
                printf "\r  Stopping %s ...(pid=%s) [OK, waiting] %s" "${JAR_FILE:-$APP_NAME}" "$psid" "$spin"
                num=$((num + 1))
                sleep 0.1
                checkpid
            done
            echo ""
            echo "[Shutdown finished]"
else
echo "[Failed]"
fi
else
echo "warn: Application is not running"
fi
}

stopImmediate() {
    checkpid
    if [ $psid -ne 0 ]; then
        echo -n "Stopping ${JAR_FILE:-$APP_NAME} ...(pid=$psid) "
        kill -9 $psid
        if [ $? -eq 0 ]; then
            echo "[OK]"
        else
            echo "[Failed]"
        fi
        checkpid
        echo "[Shutdown finished]"
    else
        echo "warn: Application is not running"
    fi
}

status() {
    checkpid
    if [ $psid -ne 0 ]; then
        echo "${JAR_FILE:-$APP_NAME} is running! (pid=$psid)"
    else
        echo "${JAR_FILE:-$APP_NAME} is not running"
    fi
}

info() {
echo "System Information:"
echo "****************************"
head -n 1 /etc/issue
uname -a
echo
echo "JAVA_HOME=$JAVA_HOME"
java -version
echo "****************************"
}

# ====================== 命令分发 =======================

case "$1" in
'start')
start
;;
'stop')
stop
;;
'stopImmediate')
stopImmediate
;;
'restart')
stop
start
;;
'status')
status
;;
'info')
info
;;
*)
echo "Usage: $0 {start|stop|stopImmediate|restart|status|info}" >&2
esac
