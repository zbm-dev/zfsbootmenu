#!/usr/bin/env perl
# vim: softtabstop=2 shiftwidth=2 expandtab

# This script is for signing ZBM EFI Images for use with Secure Boot
# It supports sbctl and sbsigntools

# Config is written at the end of the main ZBM config file (/etc/zfsbootmenu/config.yaml), and looks like this:
#SecureBoot:
#  SignBackup: true
#  DeleteUnsigned: false
#  SignMethod: sbctl
#  KeyDir: /etc/sbkeys/

print "---------- ZBM-Sign ----------\n";
use feature 'say';
use strict;
use warnings;
use File::Find;
use YAML::PP;

my @EFIBins;
my $Unsigned;
my $SignMethod;

my $ypp = YAML::PP->new(boolean => 'boolean');
my $config = $ypp->load_file('/etc/zfsbootmenu/config.yaml');
my $EFI = $config->{EFI};
my $EFI_Enabled = $EFI->{Enabled};
if (!$EFI_Enabled) {
    die "EFI images are disabled! Nothing to sign!";
}

my $Global = $config->{Global};
my $ESP = $Global->{BootMountPoint};



my $SecureBoot = $config->{SecureBoot} or die "No config found, please edit /etc/zfsbootmenu/config.yaml";
my $ZBM = "$ESP/EFI/zbm";
my $KeyDir = $SecureBoot->{KeyDir};
my $DeleteUnsigned = $SecureBoot->{DeleteUnsigned};
my $SignBackups = $SecureBoot->{SignBackup};
$SignMethod = $SecureBoot->{SignMethod};



opendir my $ZBM_dir, $ZBM
    or die "Cannot open ZBM dir: $ZBM";

if ($SignBackups) {
    @EFIBins = grep { !/signed\.efi$/i and /\.efi/i } readdir $ZBM_dir;
}
else {
    @EFIBins = grep { !/signed\.efi$/i and !/backup/i and /\.efi/i } readdir $ZBM_dir;
}

say "Found: @EFIBins";
if (!$SignMethod) {
    die "No sign method found"
}
for(@EFIBins){
     
    
    say "\nSigning $_";

    if ($SignMethod eq "sbctl") {
        system "sbctl sign $ZBM/$_"
    }
    elsif ($SignMethod eq "sbsign") {
        $Unsigned = substr($_,0,-4);
        system "sbsign --key $KeyDir/DB.key --cert $KeyDir/DB.crt $ZBM/$_ --output $ZBM/$Unsigned-signed.efi";
    }
    else {
        die "Sign method $SignMethod not valid."
    }

    if ($DeleteUnsigned && $SignMethod eq "sbctl") {
        say "sbctl signs in place, not deleting $_";
    }
    elsif ($DeleteUnsigned && $SignMethod ne "sbctl") {
        say "Deleting unsigned $_";
        system "rm $ZBM/$_";
    }
}
print "---------- FINISHED ----------\n";
