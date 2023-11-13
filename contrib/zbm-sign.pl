#!/usr/bin/env perl
# vim: softtabstop=2 shiftwidth=2 expandtab

# This script can be used to sign ZFSBootMenu EFI images for use with Secure
# Boot. It works with both `sbctl` and `sbsigntools`.
#
# Installing this script as a post-run hook for generate-zbm(5) will allow
# automatic signing of new images as they are produced by generate-zbm(8). To
# do so, make sure that the `Global` section of the generate-zbm configuration
# file includes a `PostHooksDir` key with a value that refers to an existing
# directory in your filesystem. Then, save this script in the named directory
# and set its executable bit.
#
# Run-time configuration for this hook is loaded from the ZFSBootMenu
# configuration file at `/etc/zfsbootmenu/config.yaml`. Add a `SecureBoot`
# section, which will be ignored by `generate-zbm`, to the file:
#
#     SecureBoot:
#       SignBackup: true
#       DeleteUnsigned: false
#       SignMethod: sbctl
#       KeyDir: /etc/sbkeys
#
# The configuration keys should be self-explanatory.

print "---------- ZBM-Sign ----------\n";
use feature 'say';
use strict;
use warnings;
use File::Find;
use YAML::PP;

my @EFIBins;
my $Unsigned;
my $SignMethod;

my $ypp         = YAML::PP->new( boolean => 'boolean' );
my $config      = $ypp->load_file('/etc/zfsbootmenu/config.yaml');
my $EFI         = $config->{EFI};
my $EFI_Enabled = $EFI->{Enabled};
if ( !$EFI_Enabled ) {
  die "EFI images are disabled! Nothing to sign!";
}
my $ZBM    = $EFI->{ImageDir};

my $Global = $config->{Global};
my $ESP    = $Global->{BootMountPoint};

my $SecureBoot     = $config->{SecureBoot} or die "No config found, please edit /etc/zfsbootmenu/config.yaml";
my $KeyDir         = $SecureBoot->{KeyDir};
my $DeleteUnsigned = $SecureBoot->{DeleteUnsigned};
my $SignBackups    = $SecureBoot->{SignBackup};
$SignMethod = $SecureBoot->{SignMethod};

opendir my $ZBM_dir, $ZBM
  or die "Cannot open ZBM dir: $ZBM";

if ($SignBackups) {
  @EFIBins = grep { !/signed\.efi$/i and /\.efi/i } readdir $ZBM_dir;
} else {
  @EFIBins = grep { !/signed\.efi$/i and !/backup/i and /\.efi/i } readdir $ZBM_dir;
}

say "Found: @EFIBins";
if ( !$SignMethod ) {
  die "No sign method found";
}
for (@EFIBins) {

  say "\nSigning $_";

  if ( $SignMethod eq "sbctl" ) {
    system "sbctl sign $ZBM/$_";
  } elsif ( $SignMethod eq "sbsign" ) {
    $Unsigned = substr( $_, 0, -4 );
    system "sbsign --key $KeyDir/DB.key --cert $KeyDir/DB.crt $ZBM/$_ --output $ZBM/$Unsigned-signed.efi";
  } else {
    die "Sign method $SignMethod not valid.";
  }

  if ( $DeleteUnsigned && $SignMethod eq "sbctl" ) {
    say "sbctl signs in place, not deleting $_";
  } elsif ( $DeleteUnsigned && $SignMethod ne "sbctl" ) {
    say "Deleting unsigned $_";
    system "rm $ZBM/$_";
  }
}
print "---------- FINISHED ----------\n";
