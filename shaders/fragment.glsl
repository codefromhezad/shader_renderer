
/* SHADER UNIFORMS */

uniform float   u_t;




/* SHADER CONSTANTS / LOOP INDICES */

#define MAX_SCENE_ENTITIES @macro(MAX_SCENE_ENTITIES)
#define EPSILON 0.00000001




/* SHADER DEFAULT MACROS */

@macro(SET_SCREEN_WIDTH)
@macro(SET_SCREEN_HEIGHT)
@macro(SET_SCREEN_WIDTH_2)
@macro(SET_SCREEN_HEIGHT_2)




/* GEOMETRIES IDENTIFIERS */

int GeometrySphere = 1;




/* BASE STRUCTURES */

struct Ray {
    vec3 position;
    vec3 direction;
};

struct Entity {
    /* Supported geometries: 
     * - GeometrySphere     = 1     => Regular sphere
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




/* GEOMETRIES INTERSECTIONS */

Intersection intersectSphere(Ray ray, Entity sphere) {
    Intersection intersect;

    intersect.intersected = 0;

    float t0, t1;
    vec3 L = ray.position - sphere.position;
    float radiusSquared = sphere.radius * sphere.radius;

    float a = dot(ray.direction, ray.direction);
    float b = 2.0 * dot(ray.direction, L);
    float c = dot(L, L) - radiusSquared;

    /* Solve Quadratic */
    float discr = b * b - 4.0 * a * c; 
    float x0, x1;

    if(discr < EPSILON) {
        return intersect; 
    } else if(discr - EPSILON < 0.0 && discr + EPSILON > 0.0) {
        x0 = x1 = - 0.5 * b / a; 
    } else { 
        float q = (b > 0.0) ? 
            -0.5 * (b + sqrt(discr)) : 
            -0.5 * (b - sqrt(discr)); 
        x0 = q / a; 
        x1 = c / q; 
    } 

    /* Quadratic has solution(s), continue */
    if(x0 > x1) {
        float tmpX0 = x0;
        x0 = x1;
        x1 = tmpX0;
    }

    if(t0 < EPSILON) { 
        t0 = t1;
        if(t0 < EPSILON) {
            return intersect; 
        }     
    }

    intersect.intersected = 1;
    intersect.ray_t = t0;
    intersect.entity = sphere;
    intersect.position = ray.position + t0 * ray.direction;

    return intersect;
}




/* SCENE FUNCTIONS */

Intersection castRay(Ray ray) {
    for(int i = 0; i < MAX_SCENE_ENTITIES; i++) {
        Intersection intersect;
        Entity entity = Scene_Entities[i];

        if(entity.geometry == GeometrySphere) {
            intersect = intersectSphere(ray, entity);
        } // else if ...

        return intersect;
    }
}


/* ENTRY POINT */

void main() {
    vec3 finalPixelcolor = vec3(0.0);

    /* Declaring geometries */
    Entity mySphere;
    mySphere.geometry = GeometrySphere;
    mySphere.position = vec3(0.0, 1.0, 5.0);
    mySphere.radius = 0.2;

    /* Adding geometries to scene */
    Scene_Entities[0] = mySphere;

    /* Build Source Ray */
    float screenX = (gl_FragCoord.x - SCREEN_WIDTH_2) / SCREEN_WIDTH;
    float screenY = (gl_FragCoord.y - SCREEN_HEIGHT_2) / SCREEN_HEIGHT;

    Ray sourceRay;
    sourceRay.position  = vec3(screenX, screenY + 1.0, -5.0);
    sourceRay.direction =  vec3(0.0, 0.0, 1.0);

    /* Get intersection (or not) */
    Intersection sourceIntersection = castRay(sourceRay);

    /* Set final pixel color to draw */
    if( sourceIntersection.intersected == 1 ) {
        finalPixelcolor = vec3(0.0, 0.0, 1.0);
    } else {
        finalPixelcolor = vec3(0.2, 0.2, 0.2);
    }
    

    gl_FragColor = vec4(finalPixelcolor, 1.0);
}