const fs = require('node:fs');
const path = require('node:path');
const plugin = require('tailwindcss/plugin');

// svg style for icon components
const svgStyle = ({ prefix, name, content, size }) => ({
  [`--${prefix}-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
  '-webkit-mask': `var(--${prefix}-${name})`,
  mask: `var(--${prefix}-${name})`,
  'background-color': 'currentColor',
  'vertical-align': 'middle',
  display: 'inline-block',
  width: size,
  height: size,
});

// Embeds Hero Icons (https://heroicons.com) into your app.css bundle
// See your `CoreComponents.icon/1` for more information.
exports.heroComponent = plugin(({ matchComponents, theme }) => {
  const iconsDir = path.join(__dirname, '../deps/heroicons/optimized');
  const icons = [
    ['', '/24/outline'],
    ['-solid', '/24/solid'],
    ['-mini', '/20/solid'],
    ['-micro', '/16/solid'],
  ];
  const values = icons.reduce(
    (accumulator, [suffix, dir]) =>
      fs.readdirSync(path.join(iconsDir, dir)).reduce((iconsAccumulator, file) => {
        const name = path.basename(file, '.svg') + suffix;
        iconsAccumulator[name] = { name, fullPath: path.join(iconsDir, dir, file) };
        return iconsAccumulator;
      }, accumulator),
    {},
  );

  matchComponents(
    {
      hero: ({ name, fullPath }) => {
        const content = fs
          .readFileSync(fullPath)
          .toString()
          .replace(/\r?\n|\r/g, '');
        let size = theme('spacing.6');
        if (name.endsWith('-mini')) {
          size = theme('spacing.5');
        } else if (name.endsWith('-micro')) {
          size = theme('spacing.4');
        }
        return svgStyle({ prefix: 'hero', name, content, size });
      },
    },
    { values },
  );
});

exports.lucideComponent = plugin(({ matchComponents, theme }) => {
  const iconsDir = path.join(__dirname, '../deps/lucide/icons');

  const values = fs.readdirSync(iconsDir).reduce((iconsAccumulator, file) => {
    if (file.endsWith('.svg')) {
      const name = path.basename(file, '.svg');
      iconsAccumulator[name] = { name, fullPath: path.join(iconsDir, file) };
      return iconsAccumulator;
    } else {
      return iconsAccumulator;
    }
  }, {});

  matchComponents(
    {
      lucide: ({ name, fullPath }) => {
        const content = fs
          .readFileSync(fullPath)
          .toString()
          .replace(/\r?\n|\r/g, '')
          // Remove width and height attributes we only need viewBox
          .replace('width="24"', '')
          .replace('height="24"', '');

        const size = theme('spacing.6');
        return svgStyle({ prefix: 'lucide', name, content, size });
      },
    },
    { values },
  );
});
