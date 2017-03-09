
/* SHADER DEFAULT INPUT VARS */
// vec3 gl_FragCoord

/* SHADER UNIFORMS */

uniform vec2    u_resolution;
uniform float   u_t;
uniform int     u_isMouseOver;

// Templating example : 
// (Escaped with "\" so the parser doesn't try to actually parse it in the next comment)
// \@var(num_point_lights)



/* ENTRY POINT */

void main() {

    vec3 color = vec3(0.0);

    float margin = 50.0;

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