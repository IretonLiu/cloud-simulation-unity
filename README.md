# Realtime Volumetric Cloud Rendering in Unity

A realtime volumetric renderer for clouds using raymarching. This project was first inspired by Sebastian Lagues Video on the same topic ([Video](https://www.youtube.com/watch?v=4QOcCGI6xOU))

This is a reimplementation of the cloud rendering technique first demonstrated by Andrew Schneider in his Siggraph 2015 presentation [[1]](#1) /Chapter 4 of GPU Pro 7 [[2]](#2) on the Real-time Volumetric Cloudscapes of Horizon: Zero Dawn, as well as his Siggraph 2017 presentation [[3]](#3).

<figure>
    <img src="./Images/Cloud.gif"
    alt="Result I was able to achieve">
    <figcaption>Result</figcaption>
</figure>

The above shows the results I achieve at the current stage, this is not a complete reimplementation of the techniques metioned above.

TODO:

- None of the optimization techniques mentioned in [[3]](#3) has been implemented yet.
- The lighting is not yet ideal.

## References

<a id="1">[1]</a>
Schneider A. (2015).
[The Real-time Volumetric Cloudscapes of Horizon: Zero Dawn](https://www.guerrilla-games.com/read/the-real-time-volumetric-cloudscapes-of-horizon-zero-dawn)

<a id="2">[2]</a>
Schneider A. (2016).
GPU Pro 7, Real-time Volumetric Cloudscapes, chapter 4, pages
97–127. CRC press.

<a id="3">[3]</a>
Schneider A. (2017).
[Nubis: Authoring Real-time Volumetric Cloudscapes with the Decima Engine](https://www.guerrilla-games.com/read/nubis-authoring-real-time-volumetric-cloudscapes-with-the-decima-engine)
