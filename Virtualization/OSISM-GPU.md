## Creating and managing GPU flavors in OSISM

### Why GPU flavors?

Since the public availability of ChatGPT, Aritficial Intelligence (AI) has
received a huge amount of attention, leading to impressive progress not
just with Large Language Models (LLMs), but the complete area of generative
AI, with things like image and video generation, audio transcription etc.
Despite the impressive results, the adoption into real-world productivity
outside of customer support and software development is still work-in-progress,
as we're stll learning how to best use this new technology and how to
effectively combine it with human strengths for better results.

The AI boom has lead to a massive demand for compute capacity.
Most AI workloads (in particular LLMs) require massively parallel computations
with a huge amount of parameters, emulating the neuronal networks in human
brains. Graphics Processors (GPUs = Graphical Processing Units) happen to
be a reasonably good fit with their high bandwidth video memory and their
massivly parallel architecture, being able to do a huge amount of low-precision
floating point (or integer when using quantized models) operations per seconds.
They compete with TPU (Tensor Procsessing Units) and NPU (Neural Processing
Units) which are more specialized for the matrix (tensor) multiplications that
are the most common operations.

Nvidia has invested into a software ecosystem with CUDA for using GPUs for
high performance computing for almost two decades now. It allows to program the
parallel numerical operations in a C-like language that gets compiled to run
on the shaders and other processing units in Nvidia GPUs. With their first
mover advantage, they are market leaders in producing AI hardware, though AMD,
intel, Apple and others compete increasingly sucessfully with Nvidia. Beyond CUDA,
Vulkan (and historically OpenCL) can be used to create vendor independent GPU
programs. The Python libraries (pytorch, tensorflow, ... and others) also
often support multiple backends.

In order to enable cloud compute capacity for AI, providers typically use
GPUs (or NPUs or TPUs) to provide the compute capacity needed. These GPUs
are then either exposed to users (so they can run their own local AI models
on them) or a higher-level service (e.g. offering LLMs with OpenAI's APIs)
is hosted on these machines. We will focus on the first use-case, where GPUs
are in virtual machines and containers, so users can use them for AI workloads.
With moderate hardware (such as workstation cards fron Nvidia or AMD or intel),
LLM inference is perfectly achievable, whereas AI training requires high-end
hardware. LLMs tend to be limited by the bandwidth and in particular the amount
of available high-bandwidth memory.

