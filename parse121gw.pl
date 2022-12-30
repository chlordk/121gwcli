#! /usr/bin/perl
# vim: ts=4 :

# Strict mode
use strict;
# High resolution
use Time::HiRes qw(time);
# Use localtime()
use POSIX qw(strftime);
# Switch case
use Switch;
# GetOptions used in get_options_from_array
use Getopt::Long;

my $outfile;
my $jsonfile;
my $verbose;
GetOptions ("outfile=s" => \$outfile, # string
            "jsonfile=s" => \$jsonfile, # string
            "verbose"   => \$verbose) # flag
or die("Error in command line arguments\n");

#    uint32_t serial;
#    uint8_t mainMode;
#    uint8_t mainRange;
#    uint16_t mainValue;
#    uint8_t subMode;
#    uint8_t subRange;
#    uint16_t subValue;
#    uint8_t barStatus;
#    uint8_t barValue;
#    uint8_t iconStatus[3];
#    uint8_t checksum;
    
my %Mode = (
  0,   "LowZ",
  1,   "DCV",
  2,   "ACV",
  3,   "DCmV",
  4,   "ACmV",
  5,   "°C", #"Temp",
  6,   "Hz",
  7,   "mS",
  8,   "Duty",
  9,   "Ω", #"Resistor",
  10,  "Continuity",
  11,  "Diode",
  12,  "Capacitor",
  13,  "ACuVA",
  14,  "ACmVA",
  15,  "ACVA",
  16,  "ACuA",
  17,  "DCuA",
  18,  "ACmA",
  19,  "DCmA",
  20,  "ACA",
  21,  "DCA",
  22,  "DCuVA",
  23,  "DCmVA",
  24,  "DCVA",
  100, "°C", #"SetupTempC",
  105, "°F", #"SetupTempF",
  110, "BattV", #"SetupBattery",
  120, "SetupAPO_On",
  125, "SetupAPO_Off",
  130, "SetupYear",
  135, "SetupDate",
  140, "SetupTime",
  150, "SetupBurdenVoltage",
  160, "LCD", #"SetupLCD",
  180, "dBm", #"SetupdBm",
  190, "SetupInterval"
    );

sub getScaleFactor($$) {
	my($fMode, $fScale) = @_;
	switch ($fMode) {
		case 1 { # DCV
			switch ($fScale) {
				case 0 { return 0.0001 }
				case 1 { return 0.001 }
				case 2 { return 0.01 }
			}
		}
		case 2 { # ACV
			switch ($fScale) {
				case 0 { return 0.0001 }
				case 1 { return 0.001 }
				case 2 { return 0.01 }
			}
		}
  		case 3 { # DCmV
			switch ($fScale) {
				case 0 { return 0.000001 }
				case 1 { return 0.00001 }
			}
		}
  		case 4 { # ACmV
			switch ($fScale) {
				case 0 { return 0.001 }
				case 1 { return 0.01 }
				case 2 { return 0.1 }
				case 3 { return 1 }
			}
		}
  		case 5 { # Temp
			return 0.1;
		}
  		case 6 { # Hz
			return 0.01;
		}
  		case 9 { # Ω ㏀ ㏁ Resistor
			switch ($fScale) {
        		case 0 { return 0.001 }
				case 1 { return 0.01 }
				case 2 { return 0.1 }
        		case 3 { return 1.0 }
        		case 4 { return 10.0 }
        		case 5 { return 100.0 }
        		case 6 { return 1000.0 }
			}
		}
  		case 100 { # SetupTempC
			return 0.1;
		}
  		case 110 { # SetupBattery
			switch ($fScale) {
				case 0 { return 0.01 }
				case 1 { return 0.1 }
			}
		}
  		case 180 { # SetupdBm
			switch ($fScale) {
				case 0 { return 0.01 }
				case 1 { return 0.1 }
			}
		}
	}
	return 1;
}

sub calcChecksum {
	my $cs = 0;
	foreach my $item (@_) {
		$cs ^= hex $item;
	}
	return sprintf("%02x",$cs);
}

my $OF;
if ($outfile) {
	open $OF, '>>', $outfile or die $!;
}

while (<>) {
	my $time = time;
	my $now = strftime('%F %T', localtime($time));
	$now .= sprintf ".%03d", ($time-int($time))*1000; # without rounding
	# Indication   handle = 0x0008 value: 17 85 43 21 09 86 00 00 64 01 01 02 01 21 06 40 00 8d 
	if (/^Ind.*value: ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2}) ([[:xdigit:]]{2})\s*$/) {
		my $checkSum = calcChecksum($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18);
		if ('f2' ne $checkSum) {
			if ($verbose) {
				printf "# Checksum error: (%s) $_",$checkSum;
			}
		} else {
			my $serial = "$1$2$3$4";
			my $mainMode = hex $5;
			my $mainRange = hex $6 & 0xf;
			my $mainValue = hex "$7$8"; # Big Endian
			my $subMode = hex $9;
			my $subRange = hex $10;
			my $subValue = hex "$11$12"; # Big Endian
			my $barStatus = hex $13;
			my $barValue = hex $14;
			my $iconStatus0 = $15;
			my $iconStatus1 = $16;
			my $iconStatus2 = $17;
			my $checksum = $18;
			my $mainScaleFactor = getScaleFactor($mainMode, $mainRange);
			my $mainValueFloat = sprintf("%.3f", $mainValue * $mainScaleFactor);
			my $subScaleFactor = getScaleFactor($subMode, $subRange);
			my $subValueFloat = sprintf("%.3f", $subValue * $subScaleFactor);
			my $iconStatus = sprintf("0x%02x%02x%02x",$iconStatus0,$iconStatus1,$iconStatus2);
			my $resultline = "$now\t$mainValueFloat\t$Mode{$mainMode}\t$subValueFloat\t$Mode{$subMode}\n";
			if ($verbose) {
				print "$now mainMode: $mainMode $Mode{$mainMode}, mainRange: $mainRange, mainValue: $mainValue $mainValueFloat, subMode: $subMode $Mode{$subMode}, subRange: $subRange, subValue: $subValue, barStatus: $barStatus, barValue: $barValue, iconStatus: $iconStatus, checksum: $checksum\n";
			} else {
				print "$resultline";
			}
			if ($outfile) {
				print $OF "$resultline";
				$OF->flush;
			}
			if ($jsonfile) {
				my $JF;
				open $JF, '>', $jsonfile or die $!;
				print $JF "{"
					."\"mainValueFloat\":\"$mainValueFloat\","
					."\"subValueFloat\":\"$subValueFloat\","
					."\"Mode_mainMode\":\"$Mode{$mainMode}\","
					."\"Mode_subMode\":\"$Mode{$subMode}\","
					."\"mainMode\":$mainMode,"
					."\"mainRange\":$mainRange,"
					."\"mainValue\":$mainValue,"
					."\"subMode\":$subMode,"
					."\"subRange\":$subRange,"
					."\"subValue\":$subValue,"
					."\"barStatus\":$barStatus,"
					."\"barValue\":$barValue,"
					."\"iconStatus\":\"$iconStatus\""
				."}";
				close($JF);
			}
		}
	}
}

if ($outfile) {
	close($OF);
}

