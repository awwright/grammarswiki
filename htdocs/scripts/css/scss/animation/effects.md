# Effect Examples
```scss

```


# Effect3D Examples
```scss
.card {
    @include perspective(1200px); // Stronger perspective for more dramatic effect
    position: relative;

    &__face {
        @include transition3d(); // Apply smooth transitions

        // Backface visibility for flipping effect
        backface-visibility: hidden;
        -webkit-backface-visibility: hidden;

        &--front {
            @include transform3d(0deg, 0deg, 0deg, 0, 0, 0);
        }

        &--back {
            @include transform3d(0deg, 180deg, 0deg, 0, 0, 0); // Flip back face 180deg
            position: absolute;
            top: 0;
            left: 0;
        }
    }

    // Trigger flip on hover
    &:hover {
        &__face--front {
            @include transform3d(0deg, -180deg, 0deg, 0, 0, 0); // Rotate front face to hide it
        }

        &__face--back {
            @include transform3d(0deg, 0deg, 0deg, 0, 0, 0); // Bring back face to the front
        }
    }
}

```
