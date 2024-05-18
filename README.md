# edgerouter-calltracking

This repository contains the scripts to track video calls and update a homeassistant variable using conntrack on a Ubiquiti Edgerouter, as explained on my website [here](https://i.am.eddmil.es/calltracking/).

To use this on an edgerouter, simply copy the contents of this repo to `/config/scripts` on your edgerouter, and then edit `calltracking.conf` to contain the varaibles for your network. Afterwards run `chmod +x calltracking.sh` and `chmod +x post-config.d/createcalltracking.service.sh` and then run `post-config.d/createcalltracking.service.sh` to create and start the calltracking service.

PRs are welcome for adding any additional video/voice service, or to add scripts for other linux/BSD based firewalls.
