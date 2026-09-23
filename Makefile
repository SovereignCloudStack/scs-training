#!/usr/bin/make
# 
# Create PDF for training material using pandoc
#
# (c) Kurt Garloff <s7n@garloff.de>, 6.2025
# SPDX-License-Identifier: CC-BY-SA-4.0

VIRTINPUTS = Virtualization/Front.md \
	Virtualization/Virt-Architecture.md \
	Virtualization/Kolla-OSISM.md \
	Virtualization/Ceph-Knowledge.md \
	Virtualization/OSISM-Admin.md \
	Virtualization/Virt-GPU-Support.md \
	Virtualization/Perf-Compl-Monitoring.md \
	Virtualization/Environments.md \
	Virtualization/Maintenance.md \
	Virtualization/Crash-Recovery.md \
	Virtualization/Updates.md \
	Virtualization/Support.md

ALLINPUTS = Header.md \
	 Introduction/README.md \
	 $(VIRTINPUTS) \
	 clusterstacks/cluster-stacks.md \
	 monitoring/monitoring.md \
	 registry/registry.md \
	 References/README.md

SEARCHDIRS = Virtualization:clusterstacks:monitoring:registry:Introduction

TARGET = SCS-Training-Trad.pdf
TFONT = tgschola
TARGETLUA = SCS-Training.pdf
LFONT = "Lato"

default: $(TARGETLUA)
trad: $(TARGET)
all: default trad

$(TARGET): $(ALLINPUTS) Makefile
	pandoc -V geometry:a4paper,margin=24mm -V fontfamily=$(TFONT) --resource-path=$(SEARCHDIRS) -r markdown -w pdf -o $@ $(ALLINPUTS)

$(TARGETLUA): $(ALLINPUTS) Makefile
	pandoc -V geometry:a4paper,margin=24mm -V mainfont=$(LFONT) --pdf-engine=lualatex --resource-path=$(SEARCHDIRS) -r markdown -w pdf -o $@ $(ALLINPUTS)

clean:
	rm -f $(TARGET) $(TARGETLUA)
