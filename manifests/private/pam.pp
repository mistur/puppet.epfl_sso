# Class: epfl_sso::private::pam
#
# Defined types for cross-distribution PAM configuration

class epfl_sso::private::pam {
  # Ensure that a module is active.
  define module(
    $ensure = "present",
    $debug = undef
  ) {
    # Set up pam_sss using the distribution's tools
    case $::osfamily {
      'RedHat': {
        # authconfig is prone to wreaking havoc in a variety of
        # configuration files; make sure we apply our own overrides last
        ensure_resource('anchor', 'epfl_sso::authconfig_has_run')
        Name_Service <| |> -> Anchor['epfl_sso::authconfig_has_run']

        case $title {
          'sss': {
            $_authconfig_enable_args = "--enablesssdauth"
            $_authconfig_disable_args = "--disablesssdauth"
          }
          'mkhomedir': {
            $_authconfig_enable_args = "--enablemkhomedir"
            $_authconfig_disable_args = "--disablemkhomedir"
          }
          'winbind': {
            $_authconfig_enable_args = "--enablewinbindauth"
            $_authconfig_disable_args = "--disablewinbindauth"
          }
          default: {
            $_enable_disable = $ensure ? { "present" => "enable", default => "disable" }
            fail("Don't know how to tell authconfig to ${_enable_disable} ${title}")
          }
        }

        if ($ensure == "present") {
          exec { "authconfig ${_authconfig_enable_args} --updateall":
            path => $::path,
            unless => "grep pam_${title} /etc/pam.d/system-auth-ac"
          } -> Anchor['epfl_sso::authconfig_has_run']
        } else {
          exec { "authconfig ${_authconfig_disable_args} --updateall":
            path => $::path,
            onlyif => "grep pam_${title} /etc/pam.d/system-auth-ac"
          } -> Anchor['epfl_sso::authconfig_has_run']
        }
      }

      'Debian': {
        # Le sigh. https://bugs.launchpad.net/ubuntu/+source/pam/+bug/682662
        # At least we have chicken, uh, Perl (since we are on Debian)
        $_adhoc_edit_script = "/usr/local/lib/epfl_sso/debconf-adhoc-editor"
        file { ["/usr", "/usr/local", "/usr/local/lib", "/usr/local/lib/epfl_sso"]:
          ensure => "directory"
        } ->
        file { $_adhoc_edit_script:
          mode => "0700",
          content => inline_template('#!/usr/bin/perl -w

# Managed and used by Puppet exclusively. Do not edit. Keep scrolling

use strict;

if ($ENV{DEBUG}) {
  open(STDERR, ">> /tmp/debconf-adhoc-editor.log");
}

my $module_short_name = $ENV{"PUPPET_TITLE"};
my $ensure = $ENV{"PUPPET_ENSURE"};
my $fh;

local $/;  # Slurp mode
my $pam_config_file = "/usr/share/pam-configs/$module_short_name";
open $fh, $pam_config_file;
my $pam_config = <$fh>;
close $fh; undef $fh;

my ($module_full_name) = $pam_config =~ m/^Name: (.*)$/m;

die "Unable to parse $pam_config_file" unless $module_full_name;

my $oldfile = $ARGV[0];

open $fh, $oldfile;
my $debconf_to_edit = <$fh>;
close $fh; undef $fh;

die "Unable to parse $oldfile" unless
  (my ($current_modules) = $debconf_to_edit =~ m|^libpam-runtime/profiles="(.*)"|m);

warn "current_modules is $current_modules" if $ENV{DEBUG};

my @current_modules = split m/, /, $current_modules;

if ($ensure eq "present") {
  push(@current_modules, $module_full_name) unless grep { $_ eq $module_full_name } @current_modules;
} else {
  @current_modules = grep { $_ ne $module_full_name } @current_modules;
}

my $new_modules = join ", ", @current_modules;

warn "New list of modules is $new_modules" if $ENV{DEBUG};

$debconf_to_edit =~ s|^libpam-runtime/profiles="(.*)"|libpam-runtime/profiles="$new_modules"|m
  or die "Cannot substitute in $new_modules: $1";

my $newfile = "$oldfile.new";
open(DEBCONF_NEW, ">", $newfile) or die "cannot open $newfile for writing: $!";
do {
  (print DEBCONF_NEW $debconf_to_edit) &&
  close(DEBCONF_NEW)
} or die "cannot write to $newfile: $!";
rename($newfile, $oldfile)
  or die "cannot rename() $newfile to $oldfile: $!";

exit 0;
')
        } ~>
        exec { "perl -c ${_adhoc_edit_script}":
          path => $::path,
          refreshonly => true
        }

        ensure_packages(['libpam-runtime'])

        $_condition_has_module = "grep -q pam_${title}.so /etc/pam.d/common-auth /etc/pam.d/common-password /etc/pam.d/common-account /etc/pam.d/common-session"
        case $ensure {
          "present": {
            $_what_do = "add"
            $_unless = $_condition_has_module
            $_onlyif = undef
          }
          default: {
            $_what_do = "remove"
            $_onlyif = $_condition_has_module
            $_unless = undef
          }
        }

        $_debug_env = $debug ? { undef => "", default => "DEBUG=1" }
        exec { "Run pam-auth-update to ${what_do} ${title}":
          path => $::path,
          command => "env ${_debug_env} DEBIAN_FRONTEND=editor EDITOR=$_adhoc_edit_script PUPPET_ENSURE=${ensure} PUPPET_TITLE=${title} pam-auth-update",
          unless => $_unless,
          onlyif => $_onlyif,
          require => [Package['libpam-runtime'], Exec["perl -c ${_adhoc_edit_script}"]]
        }
      }
    }
  }
}
