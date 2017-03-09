
var RELEASE_DATE = "20170309";
var MAX_PARSING_RECURSIONS = 50;

/*
 * Recursively merge properties of two objects 
 * Source: http://stackoverflow.com/questions/11197247/javascript-equivalent-of-jquerys-extend-method
 * JSBin ex: http://jsbin.com/gosevo/1/edit?html,js,output (use console)
 * Usage example: 
 * 		var settings = extend({}, defaults, config);
 */
function extend(){
    for(var i=1; i<arguments.length; i++)
        for(var key in arguments[i])
            if(arguments[i].hasOwnProperty(key))
                arguments[0][key] = arguments[i][key];
    return arguments[0];
}

var ShaderRenderer = function(settings) {

	// Renderer's "Constructor"

	/* Defaults */
	this.defaults = {
		canvas_id: null,
		fragment_shader_file: null,

		width: 400,
		height: 400,
		last_update: RELEASE_DATE
	}

	this.config = extend({}, this.defaults, settings);

	/* Init renderer DOM and data */
	this.width = this.config.width;
	this.height= this.config.height;
	this.canvas = document.getElementById(this.config.canvas_id);
	this.fragment_shader_file = this.config.fragment_shader_file;
	this.last_update = this.config.last_update;

	this.stepFrameCallback = null;

	if( this.canvas.length == 0 ) {
		console.error("Can't find any canvas with id '"+canvas_id+"'");
		return;
	}

	/* Init scene / renderer */
	this.renderer = new THREE.WebGLRenderer({canvas: this.canvas});
	this.renderer.setSize(this.width, this.height);

	this.camera = new THREE.PerspectiveCamera(45, this.width / this.height, 1, 1000);
	this.scene = new THREE.Scene();

	/* To help with arrays and for loops in the shader code :
	 * At compile time, arrays of uniforms must have a constant size,
	 * so we'll parse the shader file and write the expected size directly
	 * in the shader code before compiling it. 
	 * It's a limitation of some GLSL implementations I believe but
	 * I may be utterly wrong, I haven't tinkered with shaders for a
	 * long time. And it was actually funny to use kind-of templating
	 * tags in a GLSL source code. It's visible in shaders/fragment.glsl :
	 * - @var(var_name) will replace the statement with a value from the next object :
	 */
	this.custom_shader_variables = {
		
	};

	/* Init/setup shader data as uniforms */
	this.uniforms = {

		/* Aspect / Screen resolution */
	    u_resolution: { type: 'vec2', value: {x: this.width, y: this.height}},

	    /* Timer */
	    u_t: { type: 'f', value: 0},
	};

	/* Init shader material */
	this.shaderMaterial = new THREE.ShaderMaterial({
	    vertexShader: "void main() { gl_Position = vec4(position, 1.0); }",
	    fragmentShader: "void main() { gl_FragColor = vec4(0.0); }",
	    uniforms: this.uniforms,
	    depthWrite: false,
		depthTest: false
	});

	/* Fullscreen quad used as a screen for the fragment shader */
	this.quad = new THREE.Mesh(
		new THREE.PlaneGeometry(2, 2),
		this.shaderMaterial
	);
	this.scene.add(this.quad);





	/* "Methods" */

	this.loadFile = function(file_path, done_callback) {
		$.get(file_path+'?v='+this.last_update, function(response) {
			done_callback(response);
		}).fail( function(response) {
			console.error("Can't load '" + file_path + "': "+
				"A " + response.status + " error was returned by the server");
		});
	}

	this.registerUniform = function(uniformName, uniformType, uniformValue) {
		this.uniforms['u_'+uniformName] = {type: uniformType, value: uniformValue};
	}

	this.setUniform = function(uniformName, uniformValue) {
		this.uniforms['u_'+uniformName].value = uniformValue;
	}

	this.parseShader = function(shader_code, done_callback, recursion_level) {

		if( recursion_level === undefined ) {
			recursion_level = 0;
		}

		if( recursion_level >= MAX_PARSING_RECURSIONS ) {
			console.error("Too much recursion while parsing the shader code. Please check for syntax errors");
			return;
		}

		/* Parse @var directive */
		var var_match = shader_code.match(/[^\\]\@var\s*\(\s*([^)]+)\s*\)/i);
		if( var_match ) {
			var directive_length = var_match[0].length;
			var directive_var_name = var_match[1];
			var directive_index = var_match.index;

			if( this.custom_shader_variables[directive_var_name] === undefined ) {
				console.error('Shader file is using an unregistered template variable ('+directive_var_name+')');
				return;
			}
			
			shader_code = shader_code.substring(0, directive_index) + 
				this.custom_shader_variables[directive_var_name] + 
				shader_code.substring(directive_index + directive_length);

			this.parseShader(shader_code, done_callback, recursion_level + 1);

			return;
		}

		/* Remove eventual non ascii characters in the shader code */
		shader_code = shader_code.replace(/[^\x00-\x7F]/g, "");

		/* Everything parsed, let's execute the done callback */
		if( done_callback ) {
			done_callback(shader_code);
		}
	}

	this.compile = function() {
		var that = this;

		this.loadFile(this.fragment_shader_file, function(fragment_data) {
			that.parseShader(fragment_data, function(parsed_fragment) {
				that.shaderMaterial.fragmentShader = parsed_fragment;
				that.shaderMaterial.needsUpdate = true;

				that.renderer.render(that.scene, that.camera);
			});
		});
	}

	/* if :
	 * stepCallback === false 		>>> Will render once and stop
	 * stepCallback === undefined 	>>> Will render and loop (while updating evolving uniforms)
	 *									but without any callback on each frame
	 * stepCallback === function 	>>> Will render and loop (while updating evolving uniforms)
	 *									and run stepCallback() on each frame
	 */
	this.run = function(stepCallback) {
		this.stepFrameCallback = stepCallback;
		var that = this;

		this.compile();

		if( stepCallback !== false ) {
			function step() {
				that.shaderMaterial.uniforms.u_t.value += 0.01;

				if( that.stepFrameCallback ) {
					that.stepFrameCallback();
				}

				that.renderer.render(that.scene, that.camera);

				window.requestAnimationFrame(step);
			}

			window.requestAnimationFrame(step);
		} else {
			
			that.renderer.render(that.scene, that.camera);

		}
		
	} 
}