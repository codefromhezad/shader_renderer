
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


/* Generate unique hash from string
 * Source: http://stackoverflow.com/questions/7616461/generate-a-hash-from-string-in-javascript-jquery
 * Usage example:
 * 		var hash = original_str.to_hash();
 */
String.prototype.to_hash = function() {
	var hash = 0, i, chr;
	if (this.length === 0) return hash;
	for (i = 0; i < this.length; i++) {
		chr   = this.charCodeAt(i);
    	hash  = ((hash << 5) - hash) + chr;
    	hash |= 0; // Convert to 32bit integer
	}
  	return hash;
};



/*
 * Generate a hax color code procedurally from any string
 * Return format: #<hexcode>
 * Usage example:
 * 		"My string".to_hex_color()
 */
String.prototype.to_hex_color = function() {
	var hash = this.to_hash();

	var c = (hash & 0x00FFFFFF)
        .toString(16)
        .toUpperCase();

    return "00000".substring(0, 6 - c.length) + c;
}


var LOG = {
	ERROR: 	 	   0,  // 0 = No logs excepted fatal errors
	VERBOSE: 	   1,  // 3 = Verbose logs (Logs everything but try to avoid writing to console on frame updates)
};


var ShaderRenderer = function(settings) {

	// Renderer's "Constructor"
	var theRenderer = this;

	/* Constants */
	this.MAX_PARSING_RECURSIONS = 50;

	/* Defaults */
	this.defaults = {
		canvas_id: null,
		fragment_shader_file: null,

		width: 400,
		height: 400,
		last_update: "20170309", // Default date is when last_update setting was introduced

		log_level: LOG.ERROR,
		log_indent: '    ',
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
	 * long time. And it was actually fun to use kind of templating
	 * tags in a GLSL source code. It's visible in shaders/fragment.glsl :
	 * - @macro(macro_name) will replace the statement with a value from the next object :
	 */
	this.custom_macro_vars = {
		
	};

	/* Init/setup shader data as uniforms */
	this.uniforms = {

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

	this.log = function(log_level, message, category, indentLevel) {

		if( this.config.log_level < log_level ) {
			return;
		}

		var css_args = ['', ''];

		if( category ) {
			message = '%c['+category+']%c ' + message;
			css_args[0] = 'font-weight: bold; text-transform: uppercase; color: #'+category.to_hex_color()+';';
		}

		if( indentLevel ) {
			message = Array(indentLevel + 1).join(this.config.log_indent) + '' + message;
		}

		var log_args = [message, css_args[0], css_args[1]];

		switch( log_level ) {
			case LOG.ERROR:   console.error.apply(console, log_args); break;
			case LOG.WARN: 	  console.warn.apply(console, log_args); break;
			case LOG.INFO: 	  console.info.apply(console, log_args); break;
			case LOG.VERBOSE: console.log.apply(console, log_args); break;
		}
	}

	this.log_registered_data = function() {
		theRenderer.log(LOG.VERBOSE, '', 'Registered data');

		theRenderer.log(LOG.VERBOSE, '('+Object.keys(this.custom_macro_vars).length+')', 'Macros', 1);
		for(var m_name in this.custom_macro_vars) {
			theRenderer.log(LOG.VERBOSE, m_name + ' = "' + this.custom_macro_vars[m_name] + '"', null, 2);
		}

		theRenderer.log(LOG.VERBOSE, '('+Object.keys(this.uniforms).length+')', "Uniforms", 1);
		for(var u_name in this.uniforms) {
			theRenderer.log(LOG.VERBOSE, '<'+this.uniforms[u_name].type+'> ' + u_name + ' = '+this.uniforms[u_name].value, null, 2 );
		}
	}

	this.registerDefaultMacros = function() {
		this.registerMacro('SET_SCREEN_WIDTH',  'float SCREEN_WIDTH = ' + this.width.toFixed(1) + ';' );
		this.registerMacro('SET_SCREEN_HEIGHT', 'float SCREEN_HEIGHT = ' + this.height.toFixed(1) + ';' );
		this.registerMacro('SET_SCREEN_WIDTH_2',  'float SCREEN_WIDTH_2 = ' + (this.width / 2.0).toFixed(1) + ';' );
		this.registerMacro('SET_SCREEN_HEIGHT_2', 'float SCREEN_HEIGHT_2 = ' + (this.height / 2.0).toFixed(1) + ';' );
	}

	this.loadFile = function(file_path, done_callback) {
		$.get(file_path+'?v='+this.last_update, function(response) {
			done_callback(response);
		}).fail( function(response) {
			theRenderer.log(LOG.ERROR, "Can't load '" + file_path + "': A " + response.status + " error was returned by the server", "File", 1);
		});
	}

	this.registerUniform = function(uniformName, uniformType, uniformValue) {
		this.uniforms['u_'+uniformName] = {type: uniformType, value: uniformValue};
	}

	this.setUniform = function(uniformName, uniformValue) {
		this.uniforms['u_'+uniformName].value = uniformValue;
	}

	this.registerMacro = function(macroName, macroValue) {
		this.custom_macro_vars[macroName] = macroValue;
	}

	this.parseShader = function(shader_code, done_callback, recursion_level) {

		if( recursion_level === undefined ) {
			recursion_level = 0;
		}

		if( recursion_level >= this.MAX_PARSING_RECURSIONS ) {
			theRenderer.log(LOG.ERROR, "Too much recursion while parsing the shader code. Please check for syntax errors", "PARSING");
			return;
		}

		/* Parse @macro directive */
		var macro_match = shader_code.match(/\@macro\s*\(\s*([^)]+)\s*\)/i);
		if( macro_match ) {
			var directive_length = macro_match[0].length;
			var directive_var_name = macro_match[1];
			var directive_index = macro_match.index;

			if( this.custom_macro_vars[directive_var_name] === undefined ) {
				theRenderer.log(LOG.ERROR, 'Shader file is using an unregistered template variable ('+directive_var_name+')', "PARSING");
				return;
			}
			
			shader_code = shader_code.substring(0, directive_index) + 
				this.custom_macro_vars[directive_var_name] + 
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
		var start_date = Date.now();

		this.registerDefaultMacros();

		theRenderer.log_registered_data();

		theRenderer.log(LOG.VERBOSE, '', 'Compiling');
		theRenderer.log(LOG.VERBOSE, 'Loading fragment shader (' + theRenderer.fragment_shader_file + ')', null, 1);

		this.loadFile(this.fragment_shader_file, function(fragment_data) {

			theRenderer.log(LOG.VERBOSE, '> Done.', null, 2);
			theRenderer.log(LOG.VERBOSE, 'Parsing fragment shader (' + theRenderer.fragment_shader_file + ')', null, 1);

			theRenderer.parseShader(fragment_data, function(parsed_fragment) {
				
				theRenderer.log(LOG.VERBOSE, '> Done.', null, 2);

				theRenderer.shaderMaterial.fragmentShader = parsed_fragment;
				theRenderer.shaderMaterial.needsUpdate = true;

				theRenderer.renderer.render(theRenderer.scene, theRenderer.camera);

				theRenderer.log(LOG.VERBOSE, '', 'Rendering');
				theRenderer.log(LOG.VERBOSE, 'Render finished in '+parseInt( (Date.now() - start_date ) / 1000 ) +' seconds', null, 1);
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

		if( stepCallback ) {
			function step() {
				that.shaderMaterial.uniforms.u_t.value += 0.01;

				if( typeof that.stepFrameCallback == 'function' ) {
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