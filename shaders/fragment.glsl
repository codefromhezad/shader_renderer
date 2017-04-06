
/* SHADER UNIFORMS */

uniform vec2    u_resolution;
uniform float   u_t;
uniform int     u_isMouseOver;


/* SHADER FRONTEND / PARSED CONSTANTS */
float default_margin = @macro(default_margin);


/* ENTRY POINT */

void main() {

    vec3 color = vec3(0.0);

    float margin = default_margin;

    if( u_isMouseOver == 1 ) {
        margin = 100.0;
    }

    if( 
        gl_FragCoord.x > margin && gl_FragCoord.x < (u_resolution.x - margin) &&
        gl_FragCoord.y > margin && gl_FragCoord.y < (u_resolution.y - margin)
    ) {

        color = vec3(0.5+0.5*sin(u_t), 0.5+0.5*cos(u_t), 1.0);
    }

    gl_FragColor = vec4(color, 1.0);
}