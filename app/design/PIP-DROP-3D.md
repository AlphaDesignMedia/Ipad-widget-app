# Pip Drop look: how the 3D works (for the backbone)

Aaron's first picks are in `pip-drop-picks.json`. The working reference is `pip-drop-workshop.html`, a copy of the live workshop (https://claude.ai/artifact/6RiHNHLgMMG9ptFPHfvhc1). Open it in a browser and move the mouse.

## Rules from Aaron (30 Oct)
- Pip must read as one clear shape in silhouette. The drop is an extra on the circle; the circle still works.
- Wings and body should feel 3D, and Pip turns their head to look.
- The look is customisable. **Classic stays the default**, and one tap goes back. This needs a core "costume slot" (a Pip look list).
- Wings are Aaron's to design. Treat the current wing shapes as placeholders.

## The trick, in four parts (all cheap, no 3D engine)
1. **Body space:** Pip faces +x, y is down, z is toward you. Turning Pip is two rotations, yaw (around y) then pitch (around x), applied to points.
2. **Ball:** the orb stays a circle, and the light (highlight and gradient) stays fixed on screen. Only things *on* the ball move: the eye is a point on the surface, so it slides round and squashes (width × z) as the head turns, and hides when z < 0. That's what makes a flat circle read as a turning sphere.
3. **Drop tip:** the tail is a 3D vector, projected. When Pip faces you it points away, gets short and the drop becomes a circle. The outline is the circle plus two curved edges from the tangent points to the projected tip.
4. **Wings:** each wing is a leaf outline in its own plane: a root point, a length direction d (with a z "spread" that the flap swings), and a width direction w twisted round d by the flap. Rotate every outline point with the body and project. Sort wings by average z: far wings are drawn before the body, near wings after. Fill alpha goes with |normal.z|, so edge-on wings go thin and glassy. A rib curve from root to tip sells the curve.

**Head leads, body follows:** the head eases to its target (0.12 a frame), and the body eases to the head (0.045 a frame). With "Follow my finger" the target comes from the pointer; otherwise it's a slow idle sway scaled by `turn`.
**Reduced motion:** snap, no sway, no squash.

## Numbers
All in `picks`. `size` is the radius in points at 640 wide. `tail` is extra length × radius. `tilt` is the tail direction in degrees. `curl` bends the tip. `w1`/`w2` are wing lengths × radius. `wide` is the leaf width. `fan` is the spread in degrees. `flap` is radians a second. `depth` is the flap size. `lag` is the second wing's delay.
