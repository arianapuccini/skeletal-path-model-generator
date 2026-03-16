# skeletal-path-model-generator
Generates skeletal path compartmental models with a given number of vertices.
A skeletal path model looks like this:

 
|1| ------> |2| ------> |3| ------> |4|


However, we can add additional arrows from one compartment to another, or leaks (arrows that go nowhere).
This particular code creates models of size three vertices or less; however, changing the function input to extend the number of vertices is easy. A database with findings is attached.
