
/* SHADER UNIFORMS */

uniform float   u_t;




/* SHADER CONSTANTS / LOOP INDICES */

#define SCENE_MAX_NUM_ENTITIES @macro(SCENE_MAX_NUM_ENTITIES)
#define PATHTRACING_DEPTH @macro(PATHTRACING_DEPTH)
#define EPSILON 0.000000001
#define INF 9999999.0
#define PI 3.1415926535



/* SHADER DEFAULT MACROS */

@macro(SET_SCREEN_WIDTH)
@macro(SET_SCREEN_HEIGHT)
@macro(SET_SCREEN_WIDTH_2)
@macro(SET_SCREEN_HEIGHT_2)




/* GEOMETRIES IDENTIFIERS */

int GeometrySphere = 1;




/* MATERIAL TYPES IDENTIFIERS */

int MaterialTypePlain = 1;




/* BASE STRUCTURES */

struct Ray {
    vec3 position;
    vec3 direction;
};

struct Material {
    /* Supported types: 
     * - MaterialTypePlain  = 1     => Plain color
     */
    int type;

    /* General parameters */
    vec3 color;
};

struct Entity {
    /* Supported geometries: 
     * - GeometrySphere     = 1     => Regular sphere
     */
    int geometry; 

    /* General properties */
    Material material;

    /* General parameters */
    vec3 position;

    /* Sphere parameters */
    float radius;
};

struct Intersection {
    int intersected;
    vec3 position;
    vec3 normal;
    float ray_t;

    Entity entity;
};




/* SCENE DATA REPOSITORIES */

Entity Scene_Entities[SCENE_MAX_NUM_ENTITIES];




/* GENERAL SCENE HELPERS */

vec2 getViewCoord() {
    float screenX = (gl_FragCoord.x - SCREEN_WIDTH_2) / SCREEN_WIDTH;
    float screenY = (gl_FragCoord.y - SCREEN_HEIGHT_2) / SCREEN_HEIGHT;

    return vec2(screenX, screenY);
}




/* GEOMETRIES INTERSECTIONS */

Intersection intersectSphere(Ray ray, Entity sphere) {
    Intersection intersect;

    intersect.intersected = 0;

    vec3 L = ray.position - sphere.position;
    float radiusSquared = sphere.radius * sphere.radius;

    float a = dot(ray.direction, ray.direction);
    float b = 2.0 * dot(ray.direction, L);
    float c = dot(L, L) - radiusSquared;

    /* Solve Quadratic */
    float discr = b * b - 4.0 * a * c; 
    float x0, x1;

    if( (discr < EPSILON) && (discr > - EPSILON) ) {
        /* Quadratic has exactly one solution (Quite improbable) */
        x0 = x1 = - 0.5 * b / a; 

    } else if(discr < EPSILON) {
        /* Quadratic has no solution(s), break with "null" intersection */
        return intersect; 

    } else { 
        /* Quadratic has 2 solutions */
        float q = (b > EPSILON) ? 
            -0.5 * (b + sqrt(discr)) : 
            -0.5 * (b - sqrt(discr)); 
        x0 = q / a; 
        x1 = c / q; 
    } 
    
    /* Swap quadratic solutions if x0 is > to x1 to keep only the closest intersection */
    if(x0 > x1) {
        float tmpX0 = x0;
        x0 = x1;
        x1 = tmpX0;
    }

    if(x0 < EPSILON) { 
        x0 = x1;
        if(x0 < EPSILON) {
            /* If both solutions are < 0, intersection is behind the ray origin : return "null" intersection */
            return intersect; 
        }     
    }

    /* We found an intersection, let's build the Intersection struct and return it */
    intersect.intersected = 1;
    intersect.ray_t = x0;
    intersect.entity = sphere;
    intersect.position = ray.position + x0 * ray.direction;

    /* Calculate normal vector of intersection */
    intersect.normal = normalize(intersect.position - sphere.position);

    return intersect;
}




/* SCENE FUNCTIONS */

Intersection castRay(Ray ray) {
    Intersection finalIntersection;
    finalIntersection.intersected = 0;
    float closest_t = INF;

    for(int i = 0; i < SCENE_MAX_NUM_ENTITIES; i++) {
        Intersection intersect;
        Entity entity = Scene_Entities[i];

        if(entity.geometry == GeometrySphere) {
            intersect = intersectSphere(ray, entity);
        } // else if ... @TODO: Other geometries

        if( intersect.intersected == 1 && intersect.ray_t < closest_t ) {
            finalIntersection = intersect;
            closest_t = intersect.ray_t;
        }
    }

    return finalIntersection;
}




/* ILLUMINATION FUNCTIONS */

vec3 getIntersectionColor(Intersection intersection) {
    if(intersection.entity.material.type == MaterialTypePlain) {
        return intersection.entity.material.color;
    } // else if ... @TODO: Other material types

    // Unkown Material. Return pure black.
    return vec3(0.0);
}

vec3 getBackgroundColor(vec3 direction) {
    return vec3(0.2);
}

vec3 traceColor(Ray ray) {
    Intersection intersect = castRay(ray);

    if( intersect.intersected == 1 ) {
        return getIntersectionColor(intersect);
    } else {
        return getBackgroundColor(ray.direction);
    }
}




/* ENTRY POINT */

void main() {
    vec3 finalPixelcolor = vec3(0.0);

    /* Declaring materials */
    Material spheres_material;
    spheres_material.type  = MaterialTypePlain;
    spheres_material.color = vec3(0.85, 0.55, 0.55);

    /* Declaring geometries */
    Entity sphere1;
    sphere1.geometry = GeometrySphere;
    sphere1.material = spheres_material;
    sphere1.position = vec3(1.0, 1.5, 3.0);
    sphere1.radius = 0.8;

    Entity sphere2;
    sphere2.geometry = GeometrySphere;
    sphere2.material = spheres_material;
    sphere2.position = vec3(-1.0, 0.0, 5.0);
    sphere2.radius = 0.8;

    Entity sphere3;
    sphere3.geometry = GeometrySphere;
    sphere3.material = spheres_material;
    sphere3.position = vec3(1.0, -1.5, 0.0);
    sphere3.radius = 0.8;

    /* Adding geometries to scene */
    Scene_Entities[0] = sphere1;
    Scene_Entities[1] = sphere2;
    Scene_Entities[2] = sphere3;

    /* Build Source Ray */
    vec2 viewCoord = getViewCoord();

    Ray sourceRay;

    sourceRay.position = vec3(0.0, 0.0, -5.0);
    sourceRay.direction = normalize(vec3(viewCoord.x, viewCoord.y, 1.0));

    /* Pathtrace scene from source ray */
    finalPixelcolor = traceColor(sourceRay);
    

    gl_FragColor = vec4(finalPixelcolor, 1.0);
}