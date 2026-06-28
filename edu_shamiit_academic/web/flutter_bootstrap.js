{{flutter_js}}
{{flutter_build_config}}

// Custom bootstrapper for EduSHAMIIT Web to configure the renderer.
// Forces the 'html' renderer by default to completely bypass CanvasKit WebGL shader compilation and
// context-lost crashes under certain graphics stacks (such as Windows / Chrome), while allowing 
// runtime override using the `?renderer=canvaskit` or `?renderer=html` URL query parameter.
const urlParams = new URLSearchParams(window.location.search);
const rendererParam = urlParams.get('renderer');

const targetRenderer = (rendererParam === 'html' || rendererParam === 'canvaskit' || rendererParam === 'skwasm')
  ? rendererParam
  : 'html';

console.log('[EduSHAMIIT Bootstrap] Initializing engine with renderer: ' + targetRenderer);

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      renderer: targetRenderer,
    });
    await appRunner.runApp();
  }
});
