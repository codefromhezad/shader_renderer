
/* SHADER UNIFORMS */

uniform float   u_t;




/* SHADER CONSTANTS / LOOP INDICES */

#define SCENE_MAX_NUM_ENTITIES @macro(SCENE_MAX_NUM_ENTITIES)
#define PATHTRACING_DEPTH @macro(PATHTRACING_DEPTH)
#define EPSILON 0.00000001
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
    float albedo;
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




/* GENERAL VECTOR/MATH FUNCTIONS */
vec2 seed;
int seedInitialized = 0;
 
vec2 rand2n() {
    if( seedInitialized == 0 ) {
        seed = getViewCoord() * (u_t + 1.0);
        seedInitialized = 1;
    } else {
        seed += vec2(-1.0,1.0);
    }

    // implementation based on: lumina.sourceforge.net/Tutorials/Noise.html
    return vec2(
        fract(sin(dot(seed.xy, vec2(12.9898, 78.233))) * 43758.5453),
        fract(cos(dot(seed.xy, vec2(4.898, 7.23))) * 23421.631)
    );
}
 
vec3 ortho(vec3 v) {
    //  See : http://lolengine.net/blog/2013/09/21/picking-orthogonal-vector-combing-coconuts
    return abs(v.x) > abs(v.z) ? vec3(-v.y, v.x, 0.0)  : vec3(0.0, -v.z, v.y);
}
 
vec3 getSampleBiased(vec3 dir, float power) {
    dir = normalize(dir);
    vec3 o1 = normalize(ortho(dir));
    vec3 o2 = normalize(cross(dir, o1));
    vec2 r = rand2n();

    r.x = r.x * 2.0 * PI;
    r.y = pow(r.y, 1.0 / (power+1.0) );

    float oneminus = sqrt(1.0 - r.y * r.y);

    return cos(r.x) * oneminus * o1 + sin(r.x) * oneminus * o2 + r.y * dir;
}
 
vec3 getHemisphereSample(vec3 dir) {
    return getSampleBiased(dir, 0.0); // <- unbiased!
}
 
vec3 getCosineWeightedHemisphereSample(vec3 dir) {
    return getSampleBiased(dir, 1.0);
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

    if(discr < EPSILON) {
        /* Quadratic has no solution(s), break with "null" intersection */
        return intersect; 

    } else if(discr - EPSILON < 0.0 && discr + EPSILON > 0.0) {
        /* Quadratic has exactly one solution (Quite improbable) */
        x0 = x1 = - 0.5 * b / a; 

    } else { 
        /* Quadratic has 2 solutions */
        float q = (b > 0.0) ? 
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
    if( intersection.intersected != 1 ) {
        return vec3(0.0);
    }

    if(intersection.entity.material.type == MaterialTypePlain) {
        return intersection.entity.material.color;
    } // else if ... @TODO: Other material types

    return vec3(0.0);
}

vec3 getBackgroundColor(vec3 direction) {
    return vec3(0.9);
}

vec3 traceColor(Ray ray) {
    vec3 from = ray.position;
    vec3 dir  = ray.direction;

    vec3 hit       = vec3(0.0);
    vec3 hitNormal = vec3(0.0);
    vec3 luminance = vec3(1.0);
    float albedo   = 0.9;

    for (int i=0; i < PATHTRACING_DEPTH; i++) {

        Intersection intersect = castRay( Ray(from, dir) );

        if( intersect.intersected == 1 ) {
            hit        = intersect.position;
            hitNormal  = intersect.normal;
            dir        = getHemisphereSample(hitNormal);
            //albedo     = intersect.entity.material.albedo;   @TODO : Fix albedo retrieving from material. Probably a problem with material assignment

            luminance *= getIntersectionColor(intersect) * 2.0 * albedo * dot(dir, hitNormal);

            from = hit + hitNormal * EPSILON * 2.0;
        } else {
            return luminance * getBackgroundColor( dir );
        }
    }

    return vec3(0.0); // Ray never reached a light source
}




/* ENTRY POINT */

void main() {
    vec3 finalPixelcolor = vec3(0.0);

    /* Declaring materials */
    Material spheres_material;
    spheres_material.type  = MaterialTypePlain;
    spheres_material.color = vec3(0.75, 0.75, 0.75);
    spheres_material.albedo = 0.7;

    /* Declaring geometries */
    Entity sphere1;
    sphere1.geometry = GeometrySphere;
    sphere1.material = spheres_material;
    sphere1.position = vec3(1.0, 0.0, 2.0);
    sphere1.radius = 0.8;

    Entity sphere2;
    sphere2.geometry = GeometrySphere;
    sphere2.material = spheres_material;
    sphere2.position = vec3(-1.0, 0.0, 2.0);
    sphere2.radius = 0.8;

    /* Adding geometries to scene */
    Scene_Entities[0] = sphere1;
    Scene_Entities[1] = sphere2;

    /* Build Source Ray */
    vec2 viewCoord = getViewCoord();

    Ray sourceRay;

    sourceRay.position = vec3(0.0, 0.0, -5.0);
    sourceRay.direction = normalize(vec3(viewCoord.x, viewCoord.y, 1.0));

    /* Pathtrace scene from source ray */
    finalPixelcolor = traceColor(sourceRay);
    

    gl_FragColor = vec4(finalPixelcolor, 1.0);
}