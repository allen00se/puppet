# == Class: oradb
#
class oradb ($shout = false) {

  if $::oradb::shout {
    notify {'oradb init.pp':}
  }

  # hiera
  #hosts:
  #  'emdb.example.com':
  #    ip:                "10.10.10.15"
  #    host_aliases:      'emdb'
  #  'localhost':
  #    ip:                "127.0.0.1"
  #    host_aliases:      'localhost.localdomain,localhost4,localhost4.localdomain4'

  #$host_instances = hiera('hosts', {})
  #create_resources('host',$host_instances)

  # disable the firewall
  #service { iptables:
  #  enable    => false,
  #  ensure    => false,
  #  hasstatus => true,
  #}

  # set the swap ,forge puppet module petems-swap_file
  #class { 'swap_file':
  #  swapfile     => '/var/swap.1',
  #  swapfilesize => '8192000000'
  #}

  # set the tmpfs
  mount { '/dev/shm':
     ensure      => present,
     atboot      => true,
     device      => 'tmpfs',
     fstype      => 'tmpfs',
     options     => 'size=3500m',
  }
  
  $all_groups = ['oinstall','dba' ,'oper']

  group { $all_groups :
    ensure      => present,
  }

   user { 'oracle' :
     ensure      => present,
     uid         => 500,
     gid         => 'oinstall',
     groups      => ['oinstall','dba','oper'],
     shell       => '/bin/bash',
     password    => '$1$DSJ51vh6$4XzzwyIOk6Bi/54kglGk3.',
     home        => "/home/oracle",
     comment     => "This user oracle was created by Puppet",
     require     => Group[$all_groups],
     managehome  => true,
   }

   sysctl { 'kernel.msgmnb':                 ensure => 'present', permanent => 'yes', value => '65536',}
   sysctl { 'kernel.msgmax':                 ensure => 'present', permanent => 'yes', value => '65536',}
   sysctl { 'kernel.shmmax':                 ensure => 'present', permanent => 'yes', value => '2588483584',}
   sysctl { 'kernel.shmall':                 ensure => 'present', permanent => 'yes', value => '2097152',}
   sysctl { 'fs.file-max':                   ensure => 'present', permanent => 'yes', value => '6815744',}
   sysctl { 'net.ipv4.tcp_keepalive_time':   ensure => 'present', permanent => 'yes', value => '1800',}
   sysctl { 'net.ipv4.tcp_keepalive_intvl':  ensure => 'present', permanent => 'yes', value => '30',}
   sysctl { 'net.ipv4.tcp_keepalive_probes': ensure => 'present', permanent => 'yes', value => '5',}
   sysctl { 'net.ipv4.tcp_fin_timeout':      ensure => 'present', permanent => 'yes', value => '30',}
   sysctl { 'kernel.shmmni':                 ensure => 'present', permanent => 'yes', value => '4096', }
   sysctl { 'fs.aio-max-nr':                 ensure => 'present', permanent => 'yes', value => '1048576',}
   sysctl { 'kernel.sem':                    ensure => 'present', permanent => 'yes', value => '250 32000 100 128',}
   sysctl { 'net.ipv4.ip_local_port_range':  ensure => 'present', permanent => 'yes', value => '9000 65500',}
   sysctl { 'net.core.rmem_default':         ensure => 'present', permanent => 'yes', value => '262144',}
   sysctl { 'net.core.rmem_max':             ensure => 'present', permanent => 'yes', value => '4194304', }
   sysctl { 'net.core.wmem_default':         ensure => 'present', permanent => 'yes', value => '262144',}
   sysctl { 'net.core.wmem_max':             ensure => 'present', permanent => 'yes', value => '1048576',}

   class { 'limits':
     config => {
                '*'       => { 'nofile'  => { soft => '2048'   , hard => '8192',   },},
                'oracle'  => { 'nofile'  => { soft => '65536'  , hard => '65536',  },
                                'nproc'  => { soft => '2048'   , hard => '16384',  },
                                'stack'  => { soft => '10240'  ,},},
                },
     use_hiera => false,
   }

   $install = [ 'binutils.x86_64', 'compat-libstdc++-33.x86_64', 'glibc.x86_64','ksh.x86_64','libaio.x86_64',
                'libgcc.x86_64', 'libstdc++.x86_64', 'make.x86_64','compat-libcap1.x86_64', 'gcc.x86_64',
                'gcc-c++.x86_64','glibc-devel.x86_64','libaio-devel.x86_64','libstdc++-devel.x86_64',
                'sysstat.x86_64','unixODBC-devel','glibc.i686','libXext.x86_64','libXtst.x86_64']

   package { $install:
     ensure  => present,
   }

   $puppetDownloadMntPoint = "puppet:///modules/oradb"

   oradb::installdb{ '12.1.0.2_Linux-x86-64':
     version                => '12.1.0.2',
     file                   => 'database',
     databaseType           => 'EE',
     oracleBase             => '/oracle',
     oracleHome             => '/oracle/product/12.1/db',
     bashProfile            => true,
     user                   => 'oracle',
     group                  => 'dba',
     group_install          => 'oinstall',
     group_oper             => 'oper',
     downloadDir            => '/data/install',
     zipExtract             => true,
     puppetDownloadMntPoint => $puppetDownloadMntPoint,
   }

   oradb::listener{'start listener':
     action       => 'start',  # running|start|abort|stop
     oracleBase   => '/oracle',
     oracleHome   => '/oracle/product/12.1/db',
     user         => 'oracle',
     group        => 'dba',
     listenername => 'listener' # which is the default and optional
   }
   
   oradb::database{ 'testDb_Create':
     oracleBase              => '/oracle',
     oracleHome              => '/oracle/product/12.1/db',
     version                 => '12.1',
     user                    => 'oracle',
     group                   => 'dba',
     downloadDir             => '/tmp',
     action                  => 'create',
     dbName                  => 'test',
     dbDomain                => 'oracle.com',
     dbPort                  => '1521',
     sysPassword             => 'Welcome01',
     systemPassword          => 'Welcome01',
     dataFileDestination     => "/oracle/oradata",
     recoveryAreaDestination => "/oracle/flash_recovery_area",
     characterSet            => "AL32UTF8",
     nationalCharacterSet    => "UTF8",
     initParams              => {'open_cursors'        => '1000',
                                 'processes'           => '600',
                                 'job_queue_processes' => '4' },
     sampleSchema            => 'TRUE',
     memoryPercentage        => "40",
     memoryTotal             => "800",
     databaseType            => "MULTIPURPOSE",
     emConfiguration         => "NONE",
     require                 => Oradb::Listener['start listener'],
   }

}
