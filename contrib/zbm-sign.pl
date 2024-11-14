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
#       SignMethod: sbctl
#       KeyFileName: /etc/sbkeys/DB.key
#       CrtFileName: /etc/sbkeys/DB.crt
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
my $KeyFileName    = $SecureBoot->{KeyFileName};
my $CrtFileName    = $SecureBoot->{CrtFileName};
my $SignBackups    = $SecureBoot->{SignBackup};
$SignMethod = $SecureBoot->{SignMethod};

opendir my $ZBM_dir, $ZBM
  or die "Cannot open ZBM dir: $ZBM";

if ($SignBackups) {
  @EFIBins = sort grep { !/signed\.efi$/i and /\.efi/i } readdir $ZBM_dir;
} else {
  @EFIBins = sort grep { !/signed\.efi$/i and !/backup/i and /\.efi/i } readdir $ZBM_dir;
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
    my $verify_output = "sbverify --cert $CrtFileName $ZBM/$_ 2>&1";
    if ( $verify_output =~ /Signature verification OK/ ) {
      say "File $_ is already signed.";
      next;
    }
    system "sbsign --key $KeyFileName --cert $CrtFileName $ZBM/$_ --output $ZBM/$_";
  } else {
    die "Sign method $SignMethod not valid.";
  }
}
print "---------- FINISHED ----------\n";
