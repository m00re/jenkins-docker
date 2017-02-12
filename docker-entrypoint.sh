#!/bin/bash -x
#
# A helper script for ENTRYPOINT.
#
# If first CMD argument is 'jenkins', then the script will bootstrap Jenkins
# If CMD argument is overriden and not 'jenkins', then the user wants to run
# his own process.

set -e

if [ "$1" = 'jenkins' ]; then

  java_vm_parameters=""
  jenkins_parameters=""
  jenkins_plugins=""

  if [ -n "${JAVA_VM_PARAMETERS}" ]; then
    java_vm_parameters=${JAVA_VM_PARAMETERS}
  fi

  if [ -n "${JENKINS_PARAMETERS}" ]; then
    jenkins_parameters=${JENKINS_PARAMETERS}
  fi

  if [ -n "${JENKINS_MASTER_EXECUTORS}" ]; then
    if [ ! -d "${JENKINS_HOME}/init.groovy.d" ]; then
      mkdir ${JENKINS_HOME}/init.groovy.d
    fi
    cat > ${JENKINS_HOME}/init.groovy.d/setExecutors.groovy <<_EOF_
  import jenkins.model.*
  import hudson.security.*
  def instance = Jenkins.getInstance()
  instance.setNumExecutors(${JENKINS_MASTER_EXECUTORS})
  instance.save()
_EOF_
  fi

  if [ -n "${JENKINS_SLAVEPORT}" ]; then
    if [ ! -d "${JENKINS_HOME}/init.groovy.d" ]; then
      mkdir ${JENKINS_HOME}/init.groovy.d
    fi
    cat > ${JENKINS_HOME}/init.groovy.d/setSlaveport.groovy <<_EOF_
  import jenkins.model.*
  import java.util.logging.Logger
  def logger = Logger.getLogger("")
  def instance = Jenkins.getInstance()
  def current_slaveport = instance.getSlaveAgentPort()
  def defined_slaveport = ${JENKINS_SLAVEPORT}
  if (current_slaveport!=defined_slaveport) {
    instance.setSlaveAgentPort(defined_slaveport)
    logger.info("Slaveport set to " + defined_slaveport)
    instance.save()
  }
_EOF_
  fi

  DEFAULT_PLUGINS="matrix-auth build-timeout credentials-binding workflow-aggregator timestamper ws-cleanup swarm"

  if [ ! -n "${JENKINS_DEFAULT_PLUGINS}" ]; then
    JENKINS_PLUGINS=$JENKINS_PLUGINS" "$DEFAULT_PLUGINS
  fi

  if [ -n "${JENKINS_PLUGINS}" ]; then
    if [ ! -d "${JENKINS_HOME}/init.groovy.d" ]; then
      mkdir ${JENKINS_HOME}/init.groovy.d
    fi
    jenkins_plugins=${JENKINS_PLUGINS}
    cat > ${JENKINS_HOME}/init.groovy.d/loadPlugins.groovy <<_EOF_
    import jenkins.model.*
    import java.util.logging.Logger
    def logger = Logger.getLogger("")
    def installed = false
    def initialized = false
    def pluginParameter="${jenkins_plugins}"
    def plugins = pluginParameter.split()
    logger.info("" + plugins)
    def instance = Jenkins.getInstance()
    def pm = instance.getPluginManager()
    def uc = instance.getUpdateCenter()
    plugins.each {
      logger.info("Checking " + it)
      if (!pm.getPlugin(it)) {
        logger.info("Looking UpdateCenter for " + it)
        if (!initialized) {
          uc.updateAllSites()
          initialized = true
        }
        def plugin = uc.getPlugin(it)
        if (plugin) {
          logger.info("Installing " + it)
        	def installFuture = plugin.deploy()
          while(!installFuture.isDone()) {
            logger.info("Waiting for plugin install: " + it)
            sleep(3000)
          }
          installed = true
        }
      }
    }
    if (installed) {
      logger.info("Plugins installed, initializing a restart!")
      instance.save()
      instance.restart()
    }
_EOF_
  fi

  if [ -n "${JENKINS_ADMIN_USER}" ] && [ -n "${JENKINS_ADMIN_PASSWORD}" ]; then
    if [ ! -d "${JENKINS_HOME}/init.groovy.d" ]; then
      mkdir ${JENKINS_HOME}/init.groovy.d
    fi
    cat > ${JENKINS_HOME}/init.groovy.d/initUsers.groovy <<_EOF_
import jenkins.model.*
import hudson.security.*
import java.util.logging.Logger

def logger = Logger.getLogger("")
def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
def users = hudsonRealm.getAllUsers()

// Create new users only if this is the first startup
if (!users || users.empty) {

  // Create admin user and set authorization strategy to matrix
  hudsonRealm.createAccount("${JENKINS_ADMIN_USER}", "${JENKINS_ADMIN_PASSWORD}")
  instance.setSecurityRealm(hudsonRealm)

  // Create additional users (if specified)
  def userNames = "${JENKINS_USER_NAMES}".split(",")
  def userPasswords = "${JENKINS_USER_PASSWORDS}".split(",")
  def userPermissions = "${JENKINS_USER_PERMISSIONS}".split(",")
  if (userNames.size() == userPasswords.size() &&
      userNames.size() == userPermissions.size()) 
  {
    logger.info("Creating additional users with custom permissions:")
    for (def i = 0; i < userNames.size(); i++) {
      def name = userNames[i]
      def password = userPasswords[i]
      logger.info("--> creating user: '" + name + "'")
      hudsonRealm.createAccount(name, password)
    }
  } else {
    logger.error("The environment variables JENKINS_USER_NAMES, JENKINS_USER_PASSWORDS and JENKINS_USER_PERMISSIONS should contain an equal number of comma-separated entries")
  }
} 

// Save configuration
instance.save()

_EOF_

  cat > ${JENKINS_HOME}/init.groovy.d/setupAuthorization.groovy <<_EOF_
import jenkins.model.*
import hudson.security.*
import hudson.security.csrf.*;
import java.util.logging.Logger

def logger = Logger.getLogger("")
def instance = Jenkins.getInstance()
def pm = instance.getPluginManager()

Object getFieldValue(String path) throws Exception {
    int lastDot = path.lastIndexOf(".")
    String className = path.substring(0, lastDot)
    String fieldName = path.substring(lastDot + 1)
    Class myClass = Class.forName(className)
    return myClass.getDeclaredField(fieldName).get(null)
}

if (pm.getPlugin("matrix-auth")) {
  if (instance.getAuthorizationStrategy() instanceof GlobalMatrixAuthorizationStrategy) {
    logger.info("Skipping configuration of GlobalMatrixAuthorizationStrategy as it is already configured.")
  } else {
    logger.info("Configuring GlobalMatrixAuthorizationStrategy to secure Jenkins installation.");

    // Give admin user full administration rights
    def strategy = new GlobalMatrixAuthorizationStrategy()
    strategy.add(Jenkins.ADMINISTER, "${JENKINS_ADMIN_USER}")

    // Give users permissions based on provided configuration
    def userNames = "${JENKINS_USER_NAMES}".split(",")
    def userPermissions = "${JENKINS_USER_PERMISSIONS}".split(",")
    if (userNames.size() == userPermissions.size()) {
      logger.info("Adding user permissions:")
      for (def i = 0; i < userNames.size(); i++) {
        def name = userNames[i]
        def permissions = userPermissions[i].split(":")
        for (def j = 0; j < permissions.size(); j++) {
          def permission = permissions[j]
          try {
            strategy.add(getFieldValue(permission), name)
            logger.info("--> added permission '" + permission + "' to user '" + name + "'")
          } catch (Exception e) {
            logger.error("Failed to add permission '" + permission + "' to user '" + name + "'")
            logger.error(e.getMessage())
          }
        }
      }
    } else {
      logger.error("The environment variables JENKINS_USER_NAMES and JENKINS_USER_PERMISSIONS should contain an equal number of comma-separated entries")
    }       

    // Setting authorization strategy
    instance.setAuthorizationStrategy(strategy)

    // Enable CSRF protection, but keep compatibility with proxies
    def crumbIssuer = new DefaultCrumbIssuer(true)
    instance.setCrumbIssuer(crumbIssuer)
  }
}

instance.save()

_EOF_

  fi

  if [ -n "${JENKINS_KEYSTORE_PASSWORD}" ] && [ -n "${JENKINS_CERTIFICATE_DNAME}" ]; then
    if [ ! -f "${JENKINS_HOME}/jenkins_keystore.jks" ]; then
      ${JAVA_HOME}/bin/keytool -genkey -alias jenkins_master -keyalg RSA -keystore ${JENKINS_HOME}/jenkins_keystore.jks -storepass ${JENKINS_KEYSTORE_PASSWORD} -keypass ${JENKINS_KEYSTORE_PASSWORD} --dname "${JENKINS_CERTIFICATE_DNAME}"
    fi
    jenkins_parameters=${jenkins_parameters}' --httpPort=-1 --httpsPort=8080 --httpsKeyStore='${JENKINS_HOME}'/jenkins_keystore.jks --httpsKeyStorePassword='${JENKINS_KEYSTORE_PASSWORD}
  fi

  log_parameter=""

  if [ -n "${JENKINS_LOG_FILE}" ]; then
    log_dir=$(dirname ${JENKINS_LOG_FILE})
    log_file=$(basename ${JENKINS_LOG_FILE})
    if [ ! -d "${log_dir}" ]; then
      mkdir -p ${log_dir}
    fi
    if [ ! -f "${JENKINS_LOG_FILE}" ]; then
      touch ${JENKINS_LOG_FILE}
    fi
    log_parameter=" --logfile="${JENKINS_LOG_FILE}
  fi

  # Remove all security related information and restrict access to sensitive files
  unset JENKINS_ADMIN_USER
  unset JENKINS_ADMIN_PASSWORD
  unset JENKINS_KEYSTORE_PASSWORD
  unset JENKINS_USER_NAMES
  unset JENKINS_USER_PASSWORDS
  unset JENKINS_USER_PERMISSIONS
  chmod 600 $JENKINS_HOME/init.groovy.d/*.groovy

  # Start jenkins
  exec /usr/bin/java -Dfile.encoding=UTF-8 -Djenkins.install.runSetupWizard=false ${java_vm_parameters} -jar /usr/share/jenkins/jenkins.war ${jenkins_parameters}${log_parameter}
elif [[ "$1" == '--'* ]]; then
  # Run Jenkins with passed parameters.
  exec /usr/bin/java -Dfile.encoding=UTF-8 -Djenkins.install.runSetupWizard=false ${java_vm_parameters} -jar /usr/share/jenkins/jenkins.war "$@"
else
  exec "$@"
fi
