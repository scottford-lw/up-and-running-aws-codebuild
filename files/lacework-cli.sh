#!/bin/bash
echo "Installing the Lacework CLI"
curl https://raw.githubusercontent.com/lacework/go-sdk/master/cli/install.sh | sudo bash

echo -e "#######################################################"
echo -e "#                                                     #"
echo -e "# RUNNING LACEWORK VULNERABILITY SCAN OF LOCALHOST... #"
echo -e "#                                                     #"
echo -e "#######################################################"
echo ""

lacework vulnerability host scan-pkg-manifest --local | tee /tmp/lacework-vulnerability.out

echo ""
echo -e "#######################################################"
echo -e "#                                                     #"
echo -e "# LACEWORK VULNERABILITY SCAN COMPLETE!               #"
echo -e "#                                                     #"
echo -e "#######################################################"