

/* interval between updates (in ms) */
const unsigned int interval = 1000;

/* text to show if no value can be retrieved */
static const char unknown_str[] = "n/a";

/* maximum output string length */
#define MAXLEN 2048

/*
 * function            description                     argument (example)
 *
 * battery_perc        battery percentage              battery name (BAT0)
 *                                                     NULL on OpenBSD/FreeBSD
 * battery_remaining   battery remaining HH:MM         battery name (BAT0)
 *                                                     NULL on OpenBSD/FreeBSD
 * battery_state       battery charging state          battery name (BAT0)
 *                                                     NULL on OpenBSD/FreeBSD
 * cat                 read arbitrary file             path
 * cpu_freq            cpu frequency in MHz            NULL
 * cpu_perc            cpu usage in percent            NULL
 * datetime            date and time                   format string (%F %T)
 * disk_free           free disk space in GB           mountpoint path (/)
 * disk_perc           disk usage in percent           mountpoint path (/)
 * disk_total          total disk space in GB          mountpoint path (/)
 * disk_used           used disk space in GB           mountpoint path (/)
 * entropy             available entropy               NULL
 * gid                 GID of current user             NULL
 * hostname            hostname                        NULL
 * ipv4                IPv4 address                    interface name (eth0)
 * ipv6                IPv6 address                    interface name (eth0)
 * kernel_release      `uname -r`                      NULL
 * keyboard_indicators caps/num lock indicators        format string (c?n?)
 *                                                     see keyboard_indicators.c
 * keymap              layout (variant) of current     NULL
 *                     keymap
 * load_avg            load average                    NULL
 * netspeed_rx         receive network speed           interface name (wlan0)
 * netspeed_tx         transfer network speed          interface name (wlan0)
 * num_files           number of files in a directory  path
 *                                                     (/home/foo/Inbox/cur)
 * ram_free            free memory in GB               NULL
 * ram_perc            memory usage in percent         NULL
 * ram_total           total memory size in GB         NULL
 * ram_used            used memory in GB               NULL
 * run_command         custom shell command            command (echo foo)
 * swap_free           free swap in GB                 NULL
 * swap_perc           swap usage in percent           NULL
 * swap_total          total swap size in GB           NULL
 * swap_used           used swap in GB                 NULL
 * temp                temperature in degree celsius   sensor file
 *                                                     (/sys/class/thermal/...)
 *                                                     NULL on OpenBSD
 *                                                     thermal zone on FreeBSD
 *                                                     (tz0, tz1, etc.)
 * uid                 UID of current user             NULL
 * uptime              system uptime                   NULL
 * username            username of current user        NULL
 * vol_perc            OSS/ALSA volume in percent      mixer file (/dev/mixer)
 *                                                     NULL on OpenBSD/FreeBSD
 * wifi_essid          WiFi ESSID                      interface name (wlan0)
 * wifi_perc           WiFi signal in percent          interface name (wlan0)
 */
static const struct arg args[] = {
	/* function format          argument */
	{ cpu_perc, " cpu  %s%% |", NULL    },
	{ ram_perc, " ram %s%% |", NULL    },
	{ wifi_essid, " %s", "wlo1"    },
    { run_command, " %s |", "strength=$(iwconfig wlo1 | grep 'Link Quality=' | awk -F'=' '{print int(($2/70)*100)}'); if [ $strength -le 25 ]; then echo 󰤟; elif [ $strength -le 50 ]; then echo 󰤢; elif [ $strength -le 75 ]; then echo 󰤥; else echo 󰤨; fi" },

    { run_command, " vol %s |", "vol=$(amixer sget Master | grep -Eo '[0-9]+%' | head -n1 | tr -d '%'); [ $vol -eq 0 ] && echo 󰖁 || ([ $vol -lt 25 ] && echo 󰕿 || ([ $vol -le 75 ] && echo 󰖀 || echo 󰕾))" },

    { run_command, " bat %s ", "perc=$(cat /sys/class/power_supply/BAT1/capacity); if [ $perc -le 25 ]; then echo ${perc}% 󰁻; elif [ $perc -le 50 ]; then echo ${perc}% 󰁾; elif [ $perc -le 75 ]; then echo ${perc}% 󰂀; elif [ $perc -le 95 ]; then echo ${perc}% 󰂂; else echo ${perc}% 󰂄; fi" },

    { run_command, "%s |", "status=$(cat /sys/class/power_supply/BAT1/status); if [ \"$status\" = \"Charging\" ]; then echo 󱐋; else echo 󰚦; fi" },
	{ datetime,  " %s ", "%F %a %H:%M" },
};
