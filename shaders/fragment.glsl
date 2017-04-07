
/* SHADER UNIFORMS */

uniform vec2    u_resolution;
uniform float   u_t;
uniform int     ;




/* SHADER CONSTANTS / LOOP INDICES */

#define MAX_SCENE_ENTITIES @macro(MAX_SCENE_ENTITIES)



/* GEOMETRIES IDENTIFIERS */

int GeometrySphere = 1;




/* BASE STRUCTURES / CLASSES */

struct Ray {
    vec3 position;
    vec3 direction;
};

struct Entity {
    /* Supported geometries: 
     * - GeometrySphere (=1) => Regular sphere
     */
    int geometry; 

    /* General parameters*/
    vec3 position;

    /* Sphere parameters */
    float radius;
};

struct Intersection {
    int intersected;
    vec3 position;
    float ray_t;

    Entity entity;
};




/* SCENE DATA REPOSITORIES */

Entity Scene_Entities[MAX_SCENE_ENTITIES];




/* ENTRY POINT */

void main() {
    vec3 finalPixelcolor = vec3(0.0);

    /* Declaring geometries */
    Entity mySphere = Entity(GeometrySphere, vec3(0.0, 1.0, 1.0), 0.8);

    /* Adding geometries to scene */
    Scene_Entities[0] = mySphere;

    /* Render */
    float screenX = gl_FragCoord.x;
    float screenY = gl_FragCoord.y;

    finalPixelcolor = vec3(1.0, 0.0, 1.0);

    gl_FragColor = vec4(finalPixelcolor, 1.0);
}