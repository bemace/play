#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Play! command line script www.playframework.org/
#
# ~~~~~~~~~~~~~~~~~~~~~~ Utilities

function absname {
  if $CYGWIN; then
    return=`cygpath -ma "$1"`
  elif $MACOS; then
    if [ -d "$1" ] ; then   # a directory
      return="$(cd $1 && pwd -P)"
    elif [ -h "$1" ] ; then   # a symlink
      return="$(cd $(dirname $(readlink $1)) && pwd -P)/$(basename $1)"
    else # regular file, hopefully
      return="$(cd $(dirname $1) && pwd -P)/$(basename $1)"
    fi
  else
    return=`readlink -f $1`
  fi
}

function secret {
  if $CYGWIN; then
    i=0
    SECRET_KEY=""
    while [ $i -lt 64 ]
      do
    let HEX="$RANDOM%16"
    SECRET_KEY="$SECRET_KEY:$HEX"
    let i++
      done
    SECRET_KEY=$(echo $SECRET_KEY | sed -e 's/10/a/g' | sed -e 's/11/b/g' | sed -e 's/12/c/g' | sed -e 's/13/d/g' | sed -e 's/14/e/g' | sed -e 's/15/f/g' | sed -e 's/://g')
  else
    SECRET_KEY=`dd if=/dev/random bs=1 count=32 2>/dev/null | xxd -c 256 -ps`
  fi
}

function readConf {
  unset CONF_VALUE
  CONF_VALUE="`cat "$APPLICATION_PATH"/conf/application.conf | grep ^%$PLAY_ID.$1 | sed -e 's/^.*=//g'`"
  if [ -z $CONF_VALUE ] ; then
    CONF_VALUE="`cat "$APPLICATION_PATH"/conf/application.conf | grep ^$1 | sed -e 's/^.*=//g'`"
  fi
}

function runAppOrDie {
   [  -f "${PLAY_PID_PATH}" ] || {
  echo "~ Oops! ${APPLICATION_PATH} is not started (server.pid not found)"
  echo "~"
  exit 1
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~ Is it a real OS ?

CYGWIN=false
MACOS=false
case "`uname`" in
  CYGWIN*) CYGWIN=true;;
  Darwin*) MACOS=true;;
esac


# ~~~~~~~~~~~~~~~~~~~~~~ Display usage

function usage {
  echo "~ Usage: play command [path or current directory] "
  echo "~ "
  echo "~ with,  new      Create a new application"
  echo "~        run      Run the application in the current window"
  echo "~        debug    Run the application under JDPA debugger"
  echo "~        test     Run all tests"
  echo "~        help     Show more commands"
  echo "~"
}


function verbosedie {
  echo "~  $1"
  exit 1
}

# ~~~~~~~~~~~~~~~~~~~~~~ Where is the framework ?
absname "$0"
PLAY_BASE=`dirname "${return}"`


# ~~~~~~~~~~~~~~~~~~~~~~ Which is the framework id ?

PLAY_ID=""
if [ -f "$PLAY_BASE/id" ]; then
  PLAY_ID=`cat "$PLAY_BASE/id"`
else
  echo "" > "$PLAY_BASE/id"
fi


# ~~~~~~~~~~~~~~~~~~~~~~ Display logo

echo "~        _            _ "
echo "~  _ __ | | __ _ _  _| |"
echo "~ | '_ \\| |/ _' | || |_|"
echo "~ |  __/|_|\\____|\\__ (_)"
echo "~ |_|            |__/   "
echo "~"
if [ ! -f "${PLAY_BASE}/framework/src/play/version" ]; then
  echo "~ Oops. ${PLAY_BASE}/framework/src/play/version file not found"
  echo "~ Is Play framework compiled ? "
  echo "~"
  exit 1
fi
echo "~ play! `cat "${PLAY_BASE}/framework/src/play/version"`, http://www.playframework.org"
if [ ! -z "$PLAY_ID" ]; then
  echo "~ framework ID is $PLAY_ID"
fi
echo "~"


# ~~~~~~~~~~~~~~~~~~~~~~ Which is the command ?
if [ -z "$1" ]; then
  usage
  exit
fi

PLAY_COMMAND=$1


# ~~~~~~~~~~~~~~~~~~~~~~ [help] Display help

if [ "$PLAY_COMMAND" = "help" ] ; then
  topic=$2
  case "$topic" in
  debug)
    echo "~ debug - start application in remote debug mode"
    echo "~ "
    echo "~ Usage : play debug PATH    where PATH is the application directory to be created"
    echo "~ JPDA listens on port 8000. "
	echo "~ Application may be remotely debugged from your IDE."
    ;;
  new)
    echo "~ new - create a new Play application"
    echo "~ "
    echo "~ Usage : play new PATH - PATH is the application directory (created by play)."
    echo "~ An application skeleton is created under PATH with this structure:"
	echo "~ "
    echo "~   |   app                          Source files come here"
    echo "~   |   + controllers                Controllers package"
    echo "~   |     + Application.java         Sample controller"
    echo "~   |   + models                     Place for business objects"
    echo "~   |     + views"
    echo "~   |       + main.html              Default layout"
    echo "~   |       + Application"
    echo "~   |         + index.html           Default view for Application.index action"
    echo "~   |   conf"
    echo "~   |   + application.conf           Application settings"
    echo "~   |   + routes                     Routing configuration"
    echo "~   |   lib                          Place for external libraries"
    echo "~   |   public                       Place for static resources"
    echo "~   |   + images"
    echo "~   |   + javascripts"
    echo "~   |   + stylesheets"
    echo "~   |   test                         Place for unit tests"
    echo "~   |   + application"
    echo "~   |     + SampleTest.java          A test example"
    ;;
  start)
    echo "~ start - start application as a background process"
    echo "~ "
    echo "~ Usage : play start [PATH] - PATH represents a valid play application directory. If omitted, current directory is assumed."
    echo "~ STDOUT is redirected under logs/ directory"
    ;;
  stop)
    echo "~ stop - stop a running application"
    echo "~ "
    echo "~ Usage : play stop [PATH] - PATH is the application directory. If omitted, current directory is assumed."
    ;;
  restart)
    echo "~ restart - restart a running application"
    echo "~ "
    echo "~ Usage : play restart [PATH] - PATH is the application directory. If omitted, current directory is assumed."
    ;;
  run)
    echo "~ run - start application in the console"
    echo "~ "
    echo "~ Usage : play run [PATH] - PATH represents a valid play application directory. If omitted, current directory is assumed"
    ;;
  log)
    echo "~ log - follow application logs in console"
    echo "~ "
    echo "~ Usage : play log [PATH] - PATH is the application directory. If omitted, current directory is assumed."
    ;;
  test)
    echo "~ test - run application tests"
    echo "~ "
    echo "~ Usage : play test [PATH] - PATH represents a valid play application directory. If omitted, current directory is assumed."
    echo "~ Tests classes are located in test/ and methods must be annotated with @org.junit.Test."
    echo "~ You can define test-only settings using a %test prefix in application.conf file."
    echo "~ Refer to http://www.playframework.org/manual/contents/test for more informations."
    ;;
  id)
    echo "~ id - set or change the Play! instance ID"
    echo "~ "
    echo "~ Usage : play id"
    echo "~ Use instance ID to define alternative application settings, with a %id%. prefix : "
    echo "~  |  %local.db.pass = scott"
    echo "~  |  %demo.db.pass = tiger"
    echo "~ Please note instance ID is not application specific but global. See comments in conf/application.conf for more examples."
    ;;
  netbeansify|nb)
    echo "~ netbeansify | nb - configure a Netbeans project"
    echo "~ "
    echo "~ Usage : play netbeansify [PATH]    - PATH represents an existing play application directory. If omitted, current directory is assumed."
    echo "~ You can safely re-run command on a 'netbeansified' project."
    ;;
  eclipsify|ec)
    echo "~ eclipsify | ec - configure an Eclipse project"
    echo "~ "
    echo "~ Usage : play eclipsify [PATH] - PATH represents an existing play application directory. If omitted, current directory is assumed."
    echo "~ You can safely re-run command on an 'eclipsified' project."
    ;;
  *)
    echo "~ Play commands : "
    echo "~ "
    echo "~        new          Create a new application"
    echo "~        run          Run the application in the current window"
    echo "~        start        Start the application in background"
    echo "~        stop         Stop the application"
    echo "~        debug        Run the application under JDPA debugger"
    echo "~        log          Output latest log messages"
    echo "~        eclipsify    Create eclipse project"
    echo "~        netbeansify  Create netbeans project"
    echo "~        mkplugin     Create a Play! plugin with this application"
    echo "~        pid          Show the pid of an application"
    echo "~        clean        Delete temporary files"
    echo "~        test         Run all tests"
    echo "~        id           Define the framework ID"
    echo "~        secret       Generate a new secret key"
    echo "~        statistics   Display project statistics (soon)"
    echo "~        help         To show more commands"
    echo "~        help cmd     Show help for cmd"
    echo "~ "
    echo "~ Also refer to documentation at http://www.playframework.org/manual"
    echo "~ "
  esac
  echo "~"
  exit
fi



# ~~~~~~~~~~~~~~~~~~~~~~ [id] Define the framework ID

if [ "$PLAY_COMMAND" = "id" ] ; then
  if [ -z $PLAY_ID ]; then
    echo "~ framework ID is not set"
  fi
  echo -n "~ What is the new framework ID (or blank to unset) ? "
  read id
  if [ -z $id ]; then
    rm "$PLAY_BASE/id"
    echo "~"
    echo "~ Ok, the framework ID is unset"
    echo "~"
  else
    echo $id > "$PLAY_BASE/id"
    echo "~"
    echo "~ Ok, the framework ID is now $id"
    echo "~"
  fi
  exit
fi


# ~~~~~~~~~~~~~~~~~~~~~~ Where is the application ?

if [ -z "$2" ]; then
  APPLICATION_PATH="."
else
  APPLICATION_PATH="$2"
  REMAINING_ARGS=""
  i=1
  for arg in $@; do
  if [ $i -gt 2 ]; then
    REMAINING_ARGS="$REMAINING_ARGS $arg"
  fi
  let i=$i+1
  done
fi
if [ "$PLAY_COMMAND" = "new" ]; then
  if [ -d "$APPLICATION_PATH" ]; then
    absname "$APPLICATION_PATH"
    echo "~ Oops. ${return} already exists"
    echo "~"
    exit 1
  else
    mkdir "$APPLICATION_PATH"
  fi
fi
absname "$APPLICATION_PATH"
APPLICATION_PATH="${return}"

if [ -z "$PLAY_PID_PATH" ]; then
	PLAY_PID_PATH="${APPLICATION_PATH}/server.pid";
fi

if [ -z "$PLAY_LOG_PATH" ]; then
	PLAY_LOG_PATH="${APPLICATION_PATH}/logs/";
fi

# ~~~~~~~~~~~~~~~~~~~~~~ [new] Create a new application

if [ "$PLAY_COMMAND" = "new" ] ; then
  echo "~ The new application will be created in ${APPLICATION_PATH}"
  echo -n "~ What is the application name ? "
  read applicationName
  cp -R "${PLAY_BASE}/resources/application-skel/"* "$APPLICATION_PATH"
  sed -e "s#%APPLICATION_NAME%#$applicationName#g" "$PLAY_BASE/resources/application-skel/conf/application.conf" > "$APPLICATION_PATH/conf/application.conf.tmp"
  secret
  sed -e "s#%SECRET_KEY%#$SECRET_KEY#g" "$APPLICATION_PATH/conf/application.conf.tmp" > "$APPLICATION_PATH/conf/application.conf"
  rm "$APPLICATION_PATH/conf/application.conf.tmp"
  echo "~"
  echo "~ Ok, the application is created."
  echo "~ Start it with : play run $2"
  echo "~ Have fun !"
  echo "~"
  exit;
fi


# ~~~~~~~~~~~~~~~~~~~~~~ Check if it's a valid application

if [ ! -r "${APPLICATION_PATH}/conf/routes" ] ; then
  echo "~ Oops. ${APPLICATION_PATH} does not seem to host a valid application"
  echo "~"
  exit 1;
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [secret] Generate a new secret key

if [ "$PLAY_COMMAND" = "secret" ] ; then
  echo "~ Generating secret key..."
  secret
  if [ -z `cat "$APPLICATION_PATH/conf/application.conf" | grep application.secret` ] ; then
    echo "" >>  "$APPLICATION_PATH/conf/application.conf"
    echo "# Secret key" >>  "$APPLICATION_PATH/conf/application.conf"
    echo "application.secret=$SECRET_KEY" >>  "$APPLICATION_PATH/conf/application.conf"
  else
    mv "$APPLICATION_PATH/conf/application.conf" "$APPLICATION_PATH/conf/application.conf.tmp"
    sed -e "s#application.secret=.*#application.secret=$SECRET_KEY#g" "$APPLICATION_PATH/conf/application.conf.tmp" > "$APPLICATION_PATH/conf/application.conf"
    rm "$APPLICATION_PATH/conf/application.conf.tmp"
  fi
  echo "~ Keep the secret : $SECRET_KEY"
  echo "~"
  exit;
fi

# ~~~~~~~~~~~~~~~~~~~~~~ [clean] Clean temporary files

if [ "$PLAY_COMMAND" = "clean" ] ; then
  echo "~ Deleting $APPLICATION_PATH/tmp/*"
  rm -rf "$APPLICATION_PATH/tmp"
  echo "~"
  exit;
fi

# ~~~~~~~~~~~~~~~~~~~~~~ JAVA_HOME/bin/java is used if defined
if [ ! -d "$JAVA_HOME" ] ; then
  JAVA_PATH="java"
else
  JAVA_PATH="$JAVA_HOME/bin/java"
fi


# ~~~~~~~~~~~~~~~~~~~~~~ Read some configuration from conf/application.conf
JAVA_ARGS="$REMAINING_ARGS"

if [[ ! $JAVA_ARGS =~ .*Xmx.* ]] ; then
	readConf "jvm.memory"
	JAVA_ARGS="$JAVA_ARGS $CONF_VALUE"
fi

readConf "jpda.port"
JPDA_PORT=$CONF_VALUE
if [ -z $JPDA_PORT ] ; then
  JPDA_PORT=8000
fi

readConf "application.mode"
APPLICATION_MODE=$CONF_VALUE

if [ "$APPLICATION_MODE" = "prod" ] ; then
  JAVA_ARGS="$JAVA_ARGS -server"
fi

JAVA_ARGS="$JAVA_ARGS -Dcom.sun.management.jmxremote"

# ~~~~~~~~~~~~~~~~~~~~~~ Build classpath

AGENT_PATH="${PLAY_BASE}/framework/play.jar"

CLASSPATH="$APPLICATION_PATH/conf/"
if $CYGWIN; then
  CLASSPATH="$CLASSPATH;$PLAY_BASE/framework/play.jar"
  OLD_IFS=$IFS
  IFS=$'\n'
else
  CLASSPATH="$CLASSPATH:$PLAY_BASE/framework/play.jar"
fi
for jar in `ls -c1 "$APPLICATION_PATH/lib"/*.jar 2> /dev/null`; do
  absname "$jar"
  if $CYGWIN; then
  	CLASSPATH="$CLASSPATH;${return}";
  else
  	CLASSPATH="$CLASSPATH:${return}";
  fi
done
for jar in `ls -c1 "$PLAY_BASE/framework/lib"/*.jar 2> /dev/null`; do
  absname "$jar"
  if $CYGWIN; then
  	CLASSPATH="$CLASSPATH;$return";
  else
  	CLASSPATH="$CLASSPATH:$return";
  fi
done

	
# ~~~~~~~~~~~~~~~~~~~~~~ Modules path
readConf "modules.path"
MODULE_PATH="$CONF_VALUE"
if [ "$MODULE_PATH" == "" ] ; then
	MODULE_PATH="$APPLICATION_PATH"
fi

# Loop over module.* keys
MODULES=""

SED_SCRIPT="s|\${play.path}|${PLAY_BASE}|g"
OLD_IFS=$IFS
IFS=$'\n'
for module in `cat "$APPLICATION_PATH"/conf/application.conf | egrep '^(%$PLAY_ID.)?module.' | sed -e 's/^.*=//g'`; do
	module=`echo "$module" | sed -e $SED_SCRIPT`
	echo $module | grep ^/ > /dev/null
	if [[ $? -eq 1 ]] ; then
		module="$MODULE_PATH/$module"
	fi
	MODULES="$MODULES $module"
	for jar in `ls -c1 "$module/lib"/*.jar 2> /dev/null`; do
		absname "$jar"
		CLASSPATH="$CLASSPATH:$return";
	done
done
IFS=$OLD_IFS


# ~~~~~~~~~~~~~~~~~~~~~~ [cp] Display the application classpath

if [ "$PLAY_COMMAND" = "cp" ] ; then
  echo "~ Computed classpath is"
  echo "~ "
  echo $CLASSPATH
  echo "~ "
  exit;
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [run] Run the application

if [ "$PLAY_COMMAND" = "run" ] ; then
  echo "~ Ctrl+C to stop"
  echo "~ "
  "$JAVA_PATH" -javaagent:"$AGENT_PATH" $JAVA_ARGS -classpath "$CLASSPATH" -Djava.endorsed.dirs="$PLAY_BASE/framework/endorsed" -Dapplication.path="${APPLICATION_PATH}" -Dplay.id=$PLAY_ID play.server.Server
  echo
  exit;
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [test] Run the application tests

if [ "$PLAY_COMMAND" = "test" ] ; then
  echo "~ Running application tests..."
  echo "~ "
  "$JAVA_PATH" -javaagent:"$AGENT_PATH" $JAVA_ARGS -classpath "$CLASSPATH" -Djava.endorsed.dirs="$PLAY_BASE/framework/endorsed" -Dapplication.path="${APPLICATION_PATH}" -Dplay.id=$PLAY_ID play.test.TestRunner
  echo
  exit;
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [debug] Run the application with JPDA enabled

if [ "$PLAY_COMMAND" = "debug" ] ; then
  echo "~ Ctrl+C to break"
  echo "~ "
  echo -n "~ JPDA -> "
  "$JAVA_PATH" -javaagent:"$AGENT_PATH" $JAVA_ARGS -Xdebug -Xrunjdwp:transport=dt_socket,address=$JPDA_PORT,server=y,suspend=n -Dplay.debug=yes -classpath "$CLASSPATH" -Djava.endorsed.dirs="$PLAY_BASE/framework/endorsed" -Dapplication.path="${APPLICATION_PATH}" -Dplay.id=$PLAY_ID  play.server.Server
  echo
  exit;
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [start] Start the application in background

if [ "$PLAY_COMMAND" = "start" ] ; then
  if [ ! -r "${PLAY_LOG_PATH}" ] ; then
    mkdir -p "${PLAY_LOG_PATH}";
  fi
  if [ -f "${PLAY_PID_PATH}" ] ; then
    echo "~ Oops. $APPLICATION_PATH is already started ! (or delete ${PLAY_PID_PATH})"
    echo "~"
    exit 1
  else
    "$JAVA_PATH" -javaagent:"$AGENT_PATH" $JAVA_ARGS -classpath "$CLASSPATH" -Djava.endorsed.dirs="$PLAY_BASE/framework/endorsed" -Dapplication.path="${APPLICATION_PATH}" -Dplay.id=$PLAY_ID  play.server.Server > "${PLAY_LOG_PATH}"/system.out 2>&1 &
    echo "~ Ok, $APPLICATION_PATH is started"
    echo "~ output is redirected to ${PLAY_LOG_PATH}/system.out"
    echo $! > "${PLAY_PID_PATH}"
      echo "~ pid is `cat "${PLAY_PID_PATH}"`"
    echo "~"
    exit
  fi
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [stop] Stop the application running in background

if [ "$PLAY_COMMAND" = "stop" ] ; then
  runAppOrDie;
  echo "~ kill `cat ${PLAY_PID_PATH}`"
  kill `cat "${PLAY_PID_PATH}"`
  rm "${PLAY_PID_PATH}"
  rm "${PLAY_LOG_PATH}/system.out"
  echo "~ Ok, $APPLICATION_PATH is stopped"
  echo "~"
  exit
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [pid] Display the pid of the running application

if [ "$PLAY_COMMAND" = "pid" ] ; then
  runAppOrDie;
  echo "~ The pid for $APPLICATION_PATH is `cat "${PLAY_PID_PATH}"`"
  echo "~"
  exit
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [out] Follow logs of the running application

if [ "$PLAY_COMMAND" = "log" ] || [ "$PLAY_COMMAND" = "out" ] ; then
  runAppOrDie;
  tail -f "${PLAY_LOG_PATH}/system.out"
  exit
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [restart] Restart the running application

if [ "$PLAY_COMMAND" = "restart" ] ; then
  runAppOrDie;
  echo "~ killing process `cat "${PLAY_PID_PATH}`"
  kill `cat "${PLAY_PID_PATH}"`
  rm "${PLAY_PID_PATH}"
  rm "${PLAY_LOG_PATH}/system.out"
  echo "~ $APPLICATION_PATH is stopped"
  "$JAVA_PATH" -javaagent:"$AGENT_PATH" $JAVA_ARGS -classpath "$CLASSPATH" -Djava.endorsed.dirs="$PLAY_BASE/framework/endorsed" -Dapplication.path="${APPLICATION_PATH}" -Dplay.id=$PLAY_ID  play.server.Server > ${PLAY_LOG_PATH}/system.out 2>&1 &
  echo "~ $APPLICATION_PATH is started"
  echo "~ Output is redirected to ${PLAY_LOG_PATH}/system.out ..."
  echo $! > "${PLAY_PID_PATH}"
  echo "~ pid is `cat "${PLAY_PID_PATH}"`"
  echo "~"
  exit
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [netbeansify] Create netbeans configuration files

if [ "$PLAY_COMMAND" = "netbeansify" ] || [ "$PLAY_COMMAND" = "nb" ] ; then
  PROJECT_NAME="`cat "$APPLICATION_PATH"/conf/application.conf | grep application.name | sed -e 's/application.name=//g'`"
  rm -rf "$APPLICATION_PATH/nbproject"
  mkdir "$APPLICATION_PATH/nbproject"
  sed  -e "s|%APPLICATION_NAME%|$PROJECT_NAME|g" "$PLAY_BASE/resources/nbproject/project.xml" > "$APPLICATION_PATH/nbproject/project.xml.1.tmp"
  sed  -e "s|%ANT_SCRIPT%|$PLAY_BASE/framework/build.xml|g" "$APPLICATION_PATH/nbproject/project.xml.1.tmp" > "$APPLICATION_PATH/nbproject/project.xml.2.tmp"
  sed  -e "s|%APPLICATION_PATH%|$APPLICATION_PATH|g" "$APPLICATION_PATH/nbproject/project.xml.2.tmp" > "$APPLICATION_PATH/nbproject/project.xml.3.tmp"
  sed  -e "s|%PLAY_CLASSPATH%|$CLASSPATH|g" "$APPLICATION_PATH/nbproject/project.xml.3.tmp" > "$APPLICATION_PATH/nbproject/project.xml.4.tmp"

  # modules
  P_MODULES=""
  for m in "$MODULES"; do
	P_MODULES="<package-root>${m}/app</package-root>$P_MODULES"
  done
  sed  -e "s|%MODULES%|$P_MODULES|g" "$APPLICATION_PATH/nbproject/project.xml.4.tmp" > "$APPLICATION_PATH/nbproject/project.xml"

  rm "$APPLICATION_PATH/nbproject/project.xml.1.tmp"
  rm "$APPLICATION_PATH/nbproject/project.xml.2.tmp"
  rm "$APPLICATION_PATH/nbproject/project.xml.3.tmp"
  rm "$APPLICATION_PATH/nbproject/project.xml.4.tmp"

  echo "~ Ok, the application is ready for netbeans"
  echo "~ Just open $APPLICATION_PATH as a netbeans project"
  echo "~"
  echo "~ Use netbeansify again when you want to update netbeans configuration files"
  echo "~"
  exit
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [eclipsify] Create eclipse configuration files

if [ "$PLAY_COMMAND" = "eclipsify" ] || [ "$PLAY_COMMAND" = "ec" ] ; then
  PROJECT_NAME="`cat "$APPLICATION_PATH/conf/application.conf" | grep application.name | sed -e 's/application.name=//g'`"
  rm -rf "$APPLICATION_PATH/.project"
  rm -rf "$APPLICATION_PATH/.classpath"
  rm -rf "$APPLICATION_PATH/eclipse"
  mkdir "$APPLICATION_PATH/eclipse"
  sed  -e "s|%PROJECT_NAME%|$PROJECT_NAME|g" "$PLAY_BASE/resources/eclipse/.project" > "$APPLICATION_PATH/.project"
  if $CYGWIN; then
    IFS=";"
  else
    IFS=":"
  fi
  XML=""
  for p in $CLASSPATH; do
    if [ -f "$p" ]; then
      absname $p # really ?
      XML="$XML<classpathentry kind=\"lib\" path=\"${return}\" /> "
    fi;
  done;
  sed  -e "s|%PROJECTCLASSPATH%|${XML}|g" "$PLAY_BASE/resources/eclipse/.classpath" > "$APPLICATION_PATH/.classpath"
  sed  -e "s|%PROJECT_NAME%|$PROJECT_NAME|g" "$PLAY_BASE/resources/eclipse/play.launch" > "$APPLICATION_PATH/eclipse/$PROJECT_NAME.launch.tmp1"
  sed  -e "s|%PLAY_ID%|$PLAY_ID|g" "$APPLICATION_PATH/eclipse/$PROJECT_NAME.launch.tmp1" > "$APPLICATION_PATH/eclipse/$PROJECT_NAME.launch.tmp2"
  sed  -e "s|%PLAY_BASE%|$PLAY_BASE|g" "$APPLICATION_PATH/eclipse/$PROJECT_NAME.launch.tmp2" > "$APPLICATION_PATH/eclipse/$PROJECT_NAME.launch"
  rm -rf "$APPLICATION_PATH/eclipse/$PROJECT_NAME.launch.tmp1"
  rm -rf "$APPLICATION_PATH/eclipse/$PROJECT_NAME.launch.tmp2"

  sed  -e "s|%PROJECT_NAME%|$PROJECT_NAME|g" "$PLAY_BASE/resources/eclipse/test.launch" > "$APPLICATION_PATH/eclipse/Test $PROJECT_NAME.launch.tmp1"
  sed  -e "s|%PLAY_ID%|$PLAY_ID|g" "$APPLICATION_PATH/eclipse/Test $PROJECT_NAME.launch.tmp1" > "$APPLICATION_PATH/eclipse/Test $PROJECT_NAME.launch.tmp2"
  sed  -e "s|%PLAY_BASE%|$PLAY_BASE|g" "$APPLICATION_PATH/eclipse/Test $PROJECT_NAME.launch.tmp2" > "$APPLICATION_PATH/eclipse/Test $PROJECT_NAME.launch"
  rm -rf "$APPLICATION_PATH/eclipse/Test $PROJECT_NAME.launch.tmp1"
  rm -rf "$APPLICATION_PATH/eclipse/Test $PROJECT_NAME.launch.tmp2"

  sed  -e "s|%PROJECT_NAME%|$PROJECT_NAME|g" "$PLAY_BASE/resources/eclipse/debug.launch" > "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch.tmp1"
  sed  -e "s|%PLAY_ID%|$PLAY_ID|g" "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch.tmp1" > "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch.tmp2"
  sed  -e "s|%JPDA_PORT%|$JPDA_PORT|g" "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch.tmp1" > "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch.tmp3"
  sed  -e "s|%PLAY_BASE%|$PLAY_BASE|g" "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch.tmp3" > "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch"
  rm -rf "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch.tmp1"
  rm -rf "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch.tmp2"
  rm -rf "$APPLICATION_PATH/eclipse/JPDA $PROJECT_NAME.launch.tmp3"

  sed  -e "s|%PROJECT_NAME%|$PROJECT_NAME|g" "$PLAY_BASE/resources/eclipse/connect.launch" > "$APPLICATION_PATH/eclipse/Connect JPDA $PROJECT_NAME.launch.tmp1"
  sed  -e "s|%JPDA_PORT%|$JPDA_PORT|g" "$APPLICATION_PATH/eclipse/Connect JPDA $PROJECT_NAME.launch.tmp1" > "$APPLICATION_PATH/eclipse/Connect JPDA $PROJECT_NAME.launch"
  rm -rf "$APPLICATION_PATH/eclipse/Connect JPDA $PROJECT_NAME.launch.tmp1"

  echo "~ Ok, the application is ready for eclipse"
  echo "~ Use File/Import/General/Existing project to import $APPLICATION_PATH into eclipse"
  echo "~"
  echo "~ Use eclipsify again when you want to update eclipse configuration files."
  echo "~ However, it's often better to delete and re-import the project into your workspace since eclipse keeps dirty caches ..."
  echo "~"
  exit
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [mkplugin] Create a play! plugin from the application

if [ "$PLAY_COMMAND" = "mkplugin" ] ; then
  ( zip -h >/dev/null 2>&1)   || verbosedie "Error : zip executable required for this command"
  PROJECT_NAME="`cat ${APPLICATION_PATH}/conf/application.conf | grep application.name | sed -e 's/application.name=//g'`"
  plugin_name="${PROJECT_NAME}.zip"
  plugin_sources="public app conf data"
  cd ${APPLICATION_PATH} >/dev/null && zip "$plugin_name" -r $plugin_sources && cd $oldDir >/dev/null
  echo "~ Plugin is ready in $plugin_name"
  echo "~"
  exit 0
fi


# ~~~~~~~~~~~~~~~~~~~~~~ [statistics] Display project statistics

if [ "$PLAY_COMMAND" = "statistics" ] ; then
  PROJECT_NAME="`cat $APPLICATION_PATH/conf/application.conf | grep application.name | sed -e 's/application.name=//g'`"
  echo "~ Project name is $PROJECT_NAME"
  echo "~"
  exit
fi


# ~~~~~~~~~~~~~~~~~~~~~~ Bad command

echo "~ Oops. Unknown command : $PLAY_COMMAND"
echo "~"
usage
exit 1
