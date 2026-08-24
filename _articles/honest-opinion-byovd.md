---
title: "My Honest Opinion on BYOVD"
date: 2026-08-24 12:00:00 +0200
description: "My honest opinion on the BYOVD (Bring Your Own Vulnerable Driver) concept and its implications for blue teamers."
tags: [SOC, BYOVD]
draft: false
---

# Introduction

Before talking about BYOVD, it is important to understand the context in which this concept is being discussed. BYOVD stands for **"Bring Your Own Vulnerable Driver"** and it refers to the usage of a legitimate but vulnerable driver in order to operate at the lowest reachable level of the kernel. This leads to potential EDR bypasses. Here I want to discuss the way this concept is being presented by some researchers and the implications it has for guys like me who work in a SOC.

# What is BYOVD?

I will not deep dive into the technical details of the way a kernel driver works, but I will give a brief overview of the concept. A **kernel driver is a piece of software that runs in the kernel space and has direct access to the hardware and system resources**. It can perform privileged operations that are not available to user-mode applications.

For example, in order to monitor correctly a process, EDRs rely on kernel drivers to hook into the process and intercept its system calls. This allows them to monitor the process's behavior and detect any malicious activity.

However, if an attacker can load a vulnerable driver into the kernel, they can potentially bypass the EDR's monitoring and detection mechanisms. Once they've got that vulnerable driver loaded, they essentially have a backdoor into kernel space. From there, they can disable EDR hooks, disable telemetry, or even create a communication channel that the EDR can't see. The reason this works so well is that the EDR itself is just another piece of software running on the system—it doesn't have magical powers. If an attacker can reach the kernel with administrative privileges, they can outmaneuver whatever userland protections are in place. And the worst part? The vulnerable driver they use is often signed and legitimate, so it bypasses driver signature enforcement. It's like using the front door instead of trying to break through the window.


# Why it is bothering me as a guy working in a SOC?

In the cyber scene, there are constantly researchers popping up with daft catchphrases like “new EDR bypass in the latest version”. What really gets on my nerves about these misleading claims is that, in fact, no – you haven’t found a new bypass. You’ve certainly identified a new vulnerable driver that allows you to circumvent the EDR’s monitoring. But the underlying TTP is still the same and remains a BYOVD technique.

This sort of behaviour is difficult for blue teamers to deal with and often puts them in awkward situations. Whether managed or in-house, it’s not uncommon for the end client to ask for an explanation following the publication of this sort of article or talk. You usually end up with questions like: "I'm paying hundreds of dollars for this EDR, and yet it was bypassed again ???". And the blue teamer is left with the task of explaining that, yes, there is a new vulnerable driver that allows for EDR bypass, but no, it’s not a new technique. It’s still BYOVD, but what the customer heard is "my EDR is bypassed by a new technique" and thus thinks it's not good enough.

What I'm denouncing here is the way those researchers are presenting there findings. They are doing an amazing job at finding those drivers and help the cybersecurity world work towards a more secure future (and sincerily thank you for that guys). But they are also creating a lot of confusion and frustration for blue teamers who have to deal with the aftermath of their publications. 

# Conclusion

Let's make things clear, I'm absolutly not at war with the researchers who are publishing their findings on BYOVD. I think they are doing a great job and I appreciate their work. But I think they should be more careful about how they present their findings. They should clarify they've found new vulnerable drivers enabling BYOVD—not new techniques. 

I know this blog has nearly no visibility but if by any chance you are reading this as a researcher, please be more careful about the way you present your findings ;)

# References

- [Picus Security - BYOVD Attacks Explained](https://www.picussecurity.com/resource/blog/what-are-bring-your-own-vulnerable-driver-byovd-attacks)
- [Druva - Weaponizing Trust: How BYOVD Tactics Bypass EDR](https://www.druva.com/blog/weaponizing-trust-byovd)
- [Bitdefender - What is BYOVD](https://techzone.bitdefender.com/en/tech-explainers/what-is-bring-your-own-vulnerable-driver--byovd-.html)
- [Vectra - EDR Evasion Techniques](https://www.vectra.ai/topics/edr-evasion)
- [MINE2 - EDR Killers 2026](https://mine2.io/blog/2026-03-18-edr-killers-deception-survives/)
- [GitHub - BlackSnufkin BYOVD Research](https://github.com/BlackSnufkin/BYOVD)