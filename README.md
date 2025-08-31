# SCS Training material
[Sovereign Cloud Stack](https://scs.community/) (SCS) Training material

## Scope
This is training material to learn how to plan, setup and operate the
SCS Virtualization layer (IaaS), the SCS Container Layer (KaaS) and
the tooling used to operate it. It has been designed to support an
advanced 5d SCS training course.

## Authors
Kurt Garloff <s7n@garloff.de>
S7n Cloud Services GmbH
Cologne, Germany

Contributions:
- A significant fraction of the material is based on documentation that
  has been created by the [SCS Community](https://scs.community/) during
  the SCS project. It also contains numerous links to the
  [SCS documentation](https://docs.scs.community/)
- Karsten Samaschke (CEO VanillaCore GmbH) has created the concept for the
  cloud fundamentals training that this advanced course builds upon.
- Christian Berendt (CEO OSISM GmbH) and his company is the main developer
  behind the [OSISM](https://osism.tech/) framework used to deploy and manage
  the current implementation
  of the SCS IaaS reference implementation and also a key contributor to the
  upstream OpenStack kolla-ansible approach. Christian has accepted to review
  this course.
- The materials for the SCS Cluster Stacks, for SCS monitoring and for the
  Registry solutions was developed by [dNation](https://dnation.cloud/).

## Copyright
The work to create this material has been paid for by ITU and thus
belongs to the [ITU](https://itu.int/).

International Telecommunication Union (ITU)  
Place des Nations  
1211 Geneva 20 Switzerland

## License
It was agreed that this material will be made available under a
suitable open source license.
We have chosen the [CC-BY-SA-4.0 license](https://creativecommons.org/licenses/by-sa/4.0/deed.en).

### No warranty
While the information in this material was researched with care,
the authors can not take any responsibility for damage that may
occur from incomplete or wrong information in this material.
Any liability is excluded to the maximum extent permitted by law.

## Usage
Making this material freely available has the advantage and downside that any 
company can use it and offer trainings based on this material. A good training
course can only be delivered by trainers that have deep knowledge and experience
in deploying and running SCS infrastructure. There is currently no formal
training certification program yet by the Forum SCS-Standards at the
[OSBA](https://osb-alliance.de/)
who owns and governs the SCS trademarks. When offering SCS trainings, we
recommend to reach out to the Forum SCS-Standards <scs@osb-alliance.com>
to ensure that this can be done. We recommend trainees to ensure that
trainings are offered in alignment with the licensing terms of the ITU
and the support from the Forum SCS-Standards at the OSBA. The attribution
requirement (the BY) in the license should ensure that this note here
can be found. Derived materials need to be made available under such
terms again (the SA), so we hope that freely sharing will not lead to
abuse. Please report any copyright violation to the ITU and <s7n@garloff.de>.

## PDF
The `Makefile` allows you to build a nicely formatted PDF using PanDoc
and LuaLaTeX. Find it also on SCS' nextcloud.

## Table of Contents
### [Introduction](Introduction/)
<!--### [Recap Cloud Fundamentals](Fundamentals/)-->
### [SCS Virtualization Layer](Virtualization/)
### [SCS Container Layer](clusterstacks/)
### [SCS Monitoring](monitoring/)
### [SCS Registry](registry/)
### [SCS and GovStack links](References/)
