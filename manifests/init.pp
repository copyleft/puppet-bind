# Class: bind
#
# Install and enable an ISC BIND server.
#
# Parameters:
#  $chroot:
#   Enable chroot for the server. Default: false
#  $packagenameprefix:
#   Package prefix name. Default: 'bind' or 'bind9' depending on the OS
#
# Sample Usage :
#  include bind
#  class { 'bind':
#    chroot            => true,
#    packagenameprefix => 'bind97',
#  }
#
class bind (
  $chroot                  = false,
  $service_reload          = true,
  $servicename             = $::bind::params::servicename,
  $packagenameprefix       = $::bind::params::packagenameprefix,
  $binduser                = $::bind::params::binduser,
  $bindgroup               = $::bind::params::bindgroup,
  $service_restart_command = $::bind::params::service_restart_command,
  $rndc                    = $::bind::params::rndc,
  $rndcconf                = $::bind::params::rndcconf,
) inherits ::bind::params {

  # Chroot differences
  if $chroot == true {
    $packagenamesuffix = '-chroot'
    # Different service name with chroot on RHEL7+)
    if $::osfamily == 'RedHat' and
        versioncmp($::operatingsystemrelease, '7') >= 0 {
      $servicenamesuffix = '-chroot'
    } else {
      $servicenamesuffix = ''
    }
    $bindlogdir = '/var/named/chroot/var/log/named'
  } else {
    $packagenamesuffix = ''
    $servicenamesuffix = ''
    $bindlogdir = '/var/log/named'
  }

  # Main package and service
  class { '::bind::package':
    packagenameprefix => $packagenameprefix,
    packagenamesuffix => $packagenamesuffix,
  }
  class { '::bind::service':
    servicename    => "${servicename}${servicenamesuffix}",
    service_reload => $service_reload,
    service_restart_command => $service_restart_command,
  }

  # We want a nice log file which the package doesn't provide a location for
  file { $bindlogdir:
    ensure  => 'directory',
    owner   => $binduser,
    group   => $bindgroup,
    mode    => '0770',
    seltype => 'var_log_t',
    require => Class['::bind::package'],
    before  => Class['::bind::service'],
  }

  # disable obsolete includes from Debian package
  if $::osfamily == 'debian' {

    $content = "//\n// This include file is obsolete.\n// named.conf is Puppet managed as a single file\n//\n"

    file { '/etc/bind/named.conf.local':
      ensure => file,
      content   => $content,
      require =>  Class['bind::package'],
    }

    file { '/etc/bind/named.conf.options':
      ensure => file,
      content   => $content,
      require =>  Class['bind::package'],
    }
  }

  # Populate /etc/rndc.conf
  if $rndc {
    file {
      $rndcconf:
        ensure => file,
        owner  => $binduser,
        group  => $bindgroup,
        mode   => '0640',
        source => 'puppet:///modules/bind/rndc.conf';
      '/etc/bind/named_rndc.conf':
        ensure => file,
        owner  => $binduser,
        group  => $bindgroup,
        mode   => '0640',
        source => 'puppet:///modules/bind/named_rndc.conf';      
    }
  }
}
