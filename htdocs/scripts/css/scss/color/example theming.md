```scss
@import 'functions_color';

// Set the theme to light
.light-theme {
  $theme: $light;

  body {
    background-color: set(light);
    color: set(dark);
  }

  button {
    background-color: set(primary);
    border: 1px solid set(secondary);
    color: set(light);
  }
}

// Set the theme to dark
.dark-theme {
  $theme: $dark;

  body {
    background-color: set(dark);
    color: set(light);
  }

  button {
    background-color: set(primary);
    border: 1px solid set(secondary);
    color: set(dark);
  }
}
```

```html
<body class="light-theme">
  <!-- Your content -->
</body>

<body class="dark-theme">
  <!-- Your content -->
</body>
```