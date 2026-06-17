import requests
import sys
import time

# Ensure stdout encodes correctly to handle emojis/icons on Windows console
sys.stdout.reconfigure(encoding='utf-8')

BASE_URL = "http://127.0.0.1:80"
TEACHER_CREDS = {
    "email": "nehaupadhyay9119@gmail.com",
    "password": "naresh@1A"
}

NCERT_SYLLABUS = {
    "mathematics": [
        {
            "title": "Chapter 1: Real Numbers",
            "description": "Understanding prime factorization, fundamental theorem of arithmetic, and proofs of irrationality.",
            "topics": [
                {
                    "title": "Fundamental Theorem of Arithmetic",
                    "content": "# Fundamental Theorem of Arithmetic\n\nEvery composite number can be expressed (factorised) as a product of prime numbers, and this factorisation is unique, apart from the order in which the prime factors occur.\n\n### Mathematical Formulation\nAny composite number $x$ can be written as:\n$$x = p_1 \\cdot p_2 \\cdot \\dots \\cdot p_n$$\nwhere $p_1 \\le p_2 \\le \\dots \\le p_n$ are prime factors."
                },
                {
                    "title": "Proofs of Irrationality",
                    "content": "# Proofs of Irrationality\n\nProof by contradiction is used to establish that numbers like $\\sqrt{2}$, $\\sqrt{3}$, and $\\sqrt{5}$ are irrational.\n\n### Proof Outline for $\\sqrt{2}$:\n1. Assume $\\sqrt{2} = a/b$ where $a$ and $b$ are co-prime integers.\n2. Square both sides: $2b^2 = a^2$, implying $2$ divides $a^2$ and therefore $2$ divides $a$.\n3. Substitute $a = 2c$ to get $b^2 = 2c^2$, implying $2$ divides $b$.\n4. This contradicts that $a$ and $b$ are co-prime. Hence, $\\sqrt{2}$ is irrational."
                }
            ]
        },
        {
            "title": "Chapter 2: Polynomials",
            "description": "Analyzing the geometrical meaning of zeroes and relationship between zeroes and coefficients.",
            "topics": [
                {
                    "title": "Geometrical Meaning of Zeroes",
                    "content": "# Geometrical Meaning of Zeroes of a Polynomial\n\nThe zeroes of a polynomial $p(x)$ are precisely the x-coordinates of the points where the graph of $y = p(x)$ intersects the x-axis.\n\n- A linear polynomial has exactly one zero.\n- A quadratic polynomial can have at most two zeroes."
                },
                {
                    "title": "Zeroes and Coefficients Relationship",
                    "content": "# Relationship between Zeroes and Coefficients\n\nFor a quadratic polynomial $ax^2 + bx + c$ with zeroes $\\alpha$ and $\\beta$:\n\n- **Sum of zeroes:** $\\alpha + \\beta = -\\frac{b}{a}$\n- **Product of zeroes:** $\\alpha \\cdot \\beta = \\frac{c}{a}$"
                }
            ]
        },
        {
            "title": "Chapter 3: Linear Equations in Two Variables",
            "description": "Solving pairs of linear equations graphically and algebraically.",
            "topics": [
                {
                    "title": "Graphical Method of Solution",
                    "content": "# Graphical Method\n\nA pair of linear equations in two variables representing two lines can be:\n1. **Intersecting:** Unique solution (consistent).\n2. **Parallel:** No solution (inconsistent).\n3. **Coincident:** Infinitely many solutions (consistent dependent)."
                },
                {
                    "title": "Algebraic Methods: Substitution & Elimination",
                    "content": "# Algebraic Methods\n\nMethods to find exact solutions:\n- **Substitution:** Express one variable in terms of the other and substitute into the second equation.\n- **Elimination:** Multiply equations by constants to eliminate one variable by addition or subtraction."
                }
            ]
        },
        {
            "title": "Chapter 4: Quadratic Equations",
            "description": "Standard form, factorization method, and roots discriminant analysis.",
            "topics": [
                {
                    "title": "Solutions by Factorisation",
                    "content": "# Solving Quadratic Equations by Factorisation\n\nSplit the middle term to factorize the quadratic expression $ax^2 + bx + c = 0$ into two linear factors. Equating each factor to zero yields the roots."
                },
                {
                    "title": "Nature of Roots & Discriminant",
                    "content": "# Nature of Roots\n\nFor $ax^2 + bx + c = 0$, the discriminant is $D = b^2 - 4ac$:\n- If $D > 0$: Two distinct real roots.\n- If $D = 0$: Two equal real roots.\n- If $D < 0$: No real roots."
                }
            ]
        },
        {
            "title": "Chapter 5: Arithmetic Progressions",
            "description": "Study of sequences where difference between consecutive terms is constant.",
            "topics": [
                {
                    "title": "Finding the nth Term of an AP",
                    "content": "# The nth Term of an AP\n\nThe nth term $a_n$ of an Arithmetic Progression with first term $a$ and common difference $d$ is given by:\n$$a_n = a + (n - 1)d$$"
                },
                {
                    "title": "Sum of First n Terms of an AP",
                    "content": "# Sum of n Terms\n\nThe sum $S_n$ of the first $n$ terms of an AP is:\n$$S_n = \\frac{n}{2}[2a + (n - 1)d] = \\frac{n}{2}[a + a_n]$$"
                }
            ]
        },
        {
            "title": "Chapter 6: Triangles",
            "description": "Basic Proportionality Theorem and criteria for similarity of triangles.",
            "topics": [
                {
                    "title": "Similarity and Thales Theorem",
                    "content": "# Basic Proportionality Theorem (BPT)\n\nIf a line is drawn parallel to one side of a triangle to intersect the other two sides in distinct points, the other two sides are divided in the same ratio."
                },
                {
                    "title": "Criteria for Similarity (AAA, SAS, SSS)",
                    "content": "# Similarity Criteria\n\nTwo triangles are similar if their corresponding angles are equal and corresponding sides are in the same ratio. Criteria include:\n- **AAA** (Angle-Angle-Angle)\n- **SSS** (Side-Side-Side)\n- **SAS** (Side-Angle-Side)"
                }
            ]
        },
        {
            "title": "Chapter 7: Coordinate Geometry",
            "description": "Using coordinate grids to find distances and division points.",
            "topics": [
                {
                    "title": "Distance Formula",
                    "content": "# Distance Formula\n\nThe distance between two points $P(x_1, y_1)$ and $Q(x_2, y_2)$ is given by:\n$$d = \\sqrt{(x_2 - x_1)^2 + (y_2 - y_1)^2}$$"
                },
                {
                    "title": "Section Formula",
                    "content": "# Section Formula\n\nThe coordinates of the point $P(x, y)$ which divides the line segment joining $A(x_1, y_1)$ and $B(x_2, y_2)$ internally in the ratio $m_1 : m_2$ are:\n$$x = \\frac{m_1x_2 + m_2x_1}{m_1 + m_2}, \\quad y = \\frac{m_1y_2 + m_2y_1}{m_1 + m_2}$$"
                }
            ]
        },
        {
            "title": "Chapter 8: Introduction to Trigonometry",
            "description": "Trigonometric ratios of acute angles and basic identities.",
            "topics": [
                {
                    "title": "Trigonometric Ratios",
                    "content": "# Trigonometric Ratios\n\nFor a right-angled triangle:\n- $\\sin \\theta = \\text{Opposite} / \\text{Hypotenuse}$\n- $\\cos \\theta = \\text{Adjacent} / \\text{Hypotenuse}$\n- $\\tan \\theta = \\text{Opposite} / \\text{Adjacent}$"
                },
                {
                    "title": "Trigonometric Identities",
                    "content": "# Trigonometric Identities\n\nFundamental identities for acute angle $\\theta$:\n1. $\\sin^2 \\theta + \\cos^2 \\theta = 1$\n2. $1 + \\tan^2 \\theta = \\sec^2 \\theta$\n3. $1 + \\cot^2 \\theta = \\csc^2 \\theta$"
                }
            ]
        },
        {
            "title": "Chapter 9: Some Applications of Trigonometry",
            "description": "Calculating heights and distances using trigonometry.",
            "topics": [
                {
                    "title": "Angles of Elevation & Depression",
                    "content": "# Angles of Elevation and Depression\n\n- **Angle of Elevation:** The angle formed by the line of sight with the horizontal when the object is above the horizontal level.\n- **Angle of Depression:** The angle formed by the line of sight when the object is below the horizontal level."
                },
                {
                    "title": "Solving Heights and Distances",
                    "content": "# Heights and Distances\n\nUse trigonometric ratios (usually $\\tan \\theta$) to solve practical problems involving heights of towers, distances of ships, and widths of rivers."
                }
            ]
        },
        {
            "title": "Chapter 10: Circles",
            "description": "Properties of tangents drawn to a circle.",
            "topics": [
                {
                    "title": "Tangents to a Circle",
                    "content": "# Tangent to a Circle\n\nA tangent to a circle is a line that intersects the circle at only one point. The tangent at any point of a circle is perpendicular to the radius through the point of contact."
                },
                {
                    "title": "Tangent Lengths from an External Point",
                    "content": "# Length of Tangents\n\nThe lengths of tangents drawn from an external point to a circle are equal."
                }
            ]
        }
    ],
    "physics": [
        {
            "title": "Chapter 1: Light - Reflection",
            "description": "Laws of reflection, spherical mirrors, mirror formula.",
            "topics": [
                {
                    "title": "Reflection Laws & Spherical Mirrors",
                    "content": "# Reflection of Light\n\nLight reflection laws:\n1. The angle of incidence is equal to the angle of reflection.\n2. The incident ray, the normal, and the reflected ray lie in the same plane."
                },
                {
                    "title": "Mirror Formula & Magnification",
                    "content": "# Mirror Formula\n\n$$\\frac{1}{v} + \\frac{1}{u} = \\frac{1}{f}$$\nwhere $u$ is object distance, $v$ is image distance, and $f$ is focal length. Magnification $m = -v/u$."
                }
            ]
        },
        {
            "title": "Chapter 2: Light - Refraction",
            "description": "Laws of refraction, refractive index, refraction through a glass slab.",
            "topics": [
                {
                    "title": "Refraction Laws & Snell's Law",
                    "content": "# Refraction of Light\n\nWhen light travels from one medium to another, it bends. Snell's Law:\n$$\\frac{\\sin i}{\\sin r} = \\text{constant} = n_{21}$$"
                },
                {
                    "title": "Refractive Index & Glass Slab",
                    "content": "# Refractive Index\n\nRefractive index of medium 2 with respect to 1 is the ratio of speed of light in medium 1 to that in medium 2."
                }
            ]
        },
        {
            "title": "Chapter 3: Spherical Lenses",
            "description": "Refraction by convex and concave lenses, lens formula, and power of lens.",
            "topics": [
                {
                    "title": "Convex and Concave Lenses",
                    "content": "# Spherical Lenses\n\n- Convex lens: Converging lens, thicker in the middle.\n- Concave lens: Diverging lens, thinner in the middle."
                },
                {
                    "title": "Lens Formula and Power of Lenses",
                    "content": "# Lens Formula\n\n$$\\frac{1}{v} - \\frac{1}{u} = \\frac{1}{f}$$\nPower of lens $P = 1/f$ (in meters). Unit is Dioptre (D)."
                }
            ]
        },
        {
            "title": "Chapter 4: Human Eye and Vision Defects",
            "description": "Structure of eye, power of accommodation, Myopia, Hypermetropia.",
            "topics": [
                {
                    "title": "Eye Structure & Accommodation",
                    "content": "# The Human Eye\n\nKey components: Cornea, Iris, Pupil, Crystalline Lens, Retina, Ciliary muscles. Power of accommodation is the ability of the eye lens to adjust its focal length."
                },
                {
                    "title": "Defects: Myopia, Hypermetropia & Corrections",
                    "content": "# Defects of Vision\n\n- **Myopia (Near-sightedness):** Corrected using concave lenses.\n- **Hypermetropia (Far-sightedness):** Corrected using convex lenses."
                }
            ]
        },
        {
            "title": "Chapter 5: Prism and Dispersion",
            "description": "Refraction through a prism, white light dispersion, atmospheric refraction.",
            "topics": [
                {
                    "title": "Prism Refraction & White Light Dispersion",
                    "content": "# Dispersion of Light\n\nSplitting of white light into its component colors (VIBGYOR) when passing through a glass prism."
                },
                {
                    "title": "Atmospheric Refraction & Scattering",
                    "content": "# Atmospheric Refraction\n\nCauses phenomena like twinkling of stars and advanced sunrise. Scattering (Tyndall Effect) causes the blue color of sky and reddening of sun at sunrise/sunset."
                }
            ]
        },
        {
            "title": "Chapter 6: Electricity - Ohm's Law",
            "description": "Current, potential difference, Ohm's law, factors affecting resistance.",
            "topics": [
                {
                    "title": "Electric Current and Potential",
                    "content": "# Electric Current\n\nFlow of electric charge per unit time ($I = Q/t$). Potential difference is work done to move unit charge ($V = W/Q$)."
                },
                {
                    "title": "Ohm's Law and Resistance",
                    "content": "# Ohm's Law\n\nAt constant temperature, $V \\propto I \\implies V = IR$. Resistance $R = \\rho L / A$ where $\\rho$ is resistivity."
                }
            ]
        },
        {
            "title": "Chapter 7: Resistance Networks & Power",
            "description": "Series and parallel combination, heating effects, electric power.",
            "topics": [
                {
                    "title": "Series and Parallel Combinations",
                    "content": "# Resistor Networks\n\n- **Series:** $R_s = R_1 + R_2 + R_3$\n- **Parallel:** $1/R_p = 1/R_1 + 1/R_2 + 1/R_3$"
                },
                {
                    "title": "Heating Effect & Electric Power",
                    "content": "# Joule's Heating Effect\n\nHeat produced $H = I^2Rt$. Electric power $P = VI = I^2R = V^2/R$. Unit is Watt (W)."
                }
            ]
        },
        {
            "title": "Chapter 8: Magnetic Fields & Conductors",
            "description": "Magnetic fields, field lines, straight wire field, solenoid field.",
            "topics": [
                {
                    "title": "Magnetic Fields & Field Lines",
                    "content": "# Magnetic Fields\n\nRegion around a magnet where magnetic force is experienced. Field lines emerge from North pole and merge at South pole."
                },
                {
                    "title": "Straight Conductor & Solenoid Fields",
                    "content": "# Current-carrying Conductors\n\n- Straight wire field lines form concentric circles. Direction given by Right-hand Thumb Rule.\n- Solenoid behaves like a bar magnet."
                }
            ]
        },
        {
            "title": "Chapter 9: Force & Electromagnetic Induction",
            "description": "Fleming's rules, electromagnetic induction (EMI).",
            "topics": [
                {
                    "title": "Force on Current-carrying Conductor",
                    "content": "# Magnetic Force\n\nConductor experiences maximum force when perpendicular to magnetic field. Direction determined by Fleming's Left-hand Rule."
                },
                {
                    "title": "Electromagnetic Induction (EMI)",
                    "content": "# Electromagnetic Induction\n\nProduction of induced current in a coil due to relative motion of a magnet. Fleming's Right-hand Rule gives direction of induced current."
                }
            ]
        },
        {
            "title": "Chapter 10: Domestic Circuits & Safety",
            "description": "Live, neutral, earth wires, fuse and safety measures.",
            "topics": [
                {
                    "title": "Domestic Electric Wiring",
                    "content": "# Domestic Circuits\n\nConsists of three wires:\n- Live wire (Red insulation, 220V)\n- Neutral wire (Black insulation, 0V)\n- Earth wire (Green insulation, safety ground)"
                },
                {
                    "title": "Safety Devices: Fuse & MCB",
                    "content": "# Circuit Safety\n\nElectric fuse prevents damage from short-circuiting or overloading by melting when excessive current flows."
                }
            ]
        }
    ],
    "chemistry": [
        {
            "title": "Chapter 1: Chemical Equations",
            "description": "Writing and balancing chemical equations.",
            "topics": [
                {
                    "title": "Representing Chemical Reactions",
                    "content": "# Chemical Equations\n\nRepresenting chemical changes using symbols and formulae of reactants and products."
                },
                {
                    "title": "Balancing Chemical Equations",
                    "content": "# Balancing Equations\n\nBased on Law of Conservation of Mass: number of atoms of each element remains same before and after reaction."
                }
            ]
        },
        {
            "title": "Chapter 2: Types of Chemical Reactions",
            "description": "Combination, decomposition, displacement, double displacement, redox.",
            "topics": [
                {
                    "title": "Combination and Decomposition",
                    "content": "# Basic Reaction Types\n\n- **Combination:** Two reactants form one product.\n- **Decomposition:** One reactant breaks down into multiple products."
                },
                {
                    "title": "Displacement & Redox Reactions",
                    "content": "# Advanced Reaction Types\n\n- **Displacement:** More reactive metal displaces less reactive metal.\n- **Redox:** Simultaneous oxidation (gain of O / loss of H) and reduction."
                }
            ]
        },
        {
            "title": "Chapter 3: Effects of Oxidation and Corrosion",
            "description": "Corrosion of metals, rancidity and preventive measures.",
            "topics": [
                {
                    "title": "Corrosion of Metals",
                    "content": "# Corrosion\n\nSlow eating up of metals by action of air, moisture or chemicals (e.g., rusting of iron)."
                },
                {
                    "title": "Rancidity and Prevention",
                    "content": "# Rancidity\n\nOxidation of fats/oils in food causing bad smell and taste. Prevented using nitrogen gas flush or antioxidants."
                }
            ]
        },
        {
            "title": "Chapter 4: Acids and Bases",
            "description": "Properties of acids/bases, indicators, pH scale concept.",
            "topics": [
                {
                    "title": "Reaction with Metals & Carbonates",
                    "content": "# Chemical Properties of Acids & Bases\n\n- Acids react with metals to release Hydrogen gas.\n- Acids react with metal carbonates to release Carbon Dioxide gas."
                },
                {
                    "title": "pH Scale Concept",
                    "content": "# pH Scale\n\nMeasures hydrogen ion concentration. pH < 7 is acidic, pH = 7 is neutral, pH > 7 is basic."
                }
            ]
        },
        {
            "title": "Chapter 5: Salts & Uses",
            "description": "Sodium hydroxide, baking soda, washing soda, plaster of paris.",
            "topics": [
                {
                    "title": "Common Salt Derivatives",
                    "content": "# Derivatives from NaCl\n\nIncludes Sodium Hydroxide (Chlor-alkali process), Bleaching Powder ($CaOCl_2$), and Baking Soda ($NaHCO_3$)."
                },
                {
                    "title": "Washing Soda & Plaster of Paris",
                    "content": "# Washing Soda and POP\n\n- Washing Soda: $Na_2CO_3 \\cdot 10H_2O$\n- Plaster of Paris: Calcium Sulphate Hemihydrate ($CaSO_4 \\cdot \\frac{1}{2}H_2O$)."
                }
            ]
        },
        {
            "title": "Chapter 6: Metals and Non-metals",
            "description": "Physical and chemical properties, reactivity series.",
            "topics": [
                {
                    "title": "Physical & Chemical Properties",
                    "content": "# Properties of Metals & Non-metals\n\nMetals are malleable, ductile, sonorous and conduct electricity. Non-metals are generally brittle and poor conductors."
                },
                {
                    "title": "Reactivity Series",
                    "content": "# Reactivity Series\n\nArrangement of metals in vertical column in order of decreasing activities: K > Na > Ca > Mg > Al > Zn > Fe > Pb > H > Cu > Ag > Au."
                }
            ]
        },
        {
            "title": "Chapter 7: Ionic Bonding and Metallurgy",
            "description": "Ionic compound properties, metal extraction steps.",
            "topics": [
                {
                    "title": "Ionic Compounds Properties",
                    "content": "# Ionic Bonding\n\nFormed by transfer of electrons. Properties: High melting points, soluble in water, conduct electricity in molten state."
                },
                {
                    "title": "Extraction of Metals & Prevention",
                    "content": "# Metallurgy\n\nSteps: Enrichment of ore, reduction to metal, refining. Corrosion prevention includes galvanisation, anodising, and alloying."
                }
            ]
        },
        {
            "title": "Chapter 8: Carbon - Covalent Bonding",
            "description": "Versatility of carbon, saturated/unsaturated hydrocarbons.",
            "topics": [
                {
                    "title": "Versatile Nature of Carbon",
                    "content": "# Versatility of Carbon\n\nDue to tetravalency and catenation (ability to form long chains and rings)."
                },
                {
                    "title": "Hydrocarbons & Homologous Series",
                    "content": "# Saturated & Unsaturated Carbon\n\n- Saturated: Single bonds (Alkanes).\n- Unsaturated: Double/triple bonds (Alkenes/Alkynes).\n- Homologous Series: Group of carbon compounds with same functional group."
                }
            ]
        },
        {
            "title": "Chapter 9: Nomenclature & Properties",
            "description": "Functional groups, IUPAC nomenclature, carbon reactions.",
            "topics": [
                {
                    "title": "IUPAC Nomenclature",
                    "content": "# Nomenclature\n\nNaming carbon chains using prefixes/suffixes for functional groups (Halogens, Alcohol, Aldehyde, Ketone, Carboxylic acid)."
                },
                {
                    "title": "Addition & Substitution Reactions",
                    "content": "# Chemical Reactions\n\n- Combustion releases $CO_2$ and heat.\n- Saturated compounds undergo Substitution.\n- Unsaturated compounds undergo Addition (hydrogenation)."
                }
            ]
        },
        {
            "title": "Chapter 10: Ethanol & Detergents",
            "description": "Ethanol, ethanoic acid, soaps, cleansing mechanism.",
            "topics": [
                {
                    "title": "Ethanol & Ethanoic Acid Properties",
                    "content": "# Ethanol & Ethanoic Acid\n\n- Ethanol ($C_2H_5OH$): Reacts with sodium to release hydrogen.\n- Ethanoic acid ($CH_3COOH$): Reacts with bases to form salt and water (esterification)."
                },
                {
                    "title": "Soaps & Cleansing Mechanism",
                    "content": "# Soaps and Detergents\n\nSoap molecules form micelles around dirt, with hydrophobic tails pointing inward and hydrophilic heads pointing outward."
                }
            ]
        }
    ],
    "english": [
        {
            "title": "Chapter 1: A Letter to God",
            "description": "Lencho's absolute faith in God and the irony of his situation.",
            "topics": [
                {
                    "title": "Summary and Lencho's Character",
                    "content": "# A Letter to God\n\nStory of a hardworking farmer Lencho whose crops are destroyed by hailstorm. He writes a letter to God asking for 100 pesos."
                },
                {
                    "title": "Irony of the Post Office Employees",
                    "content": "# The Irony\n\nPostmaster collects 70 pesos to keep Lencho's faith alive. But Lencho believes post office employees stole the remaining 30 pesos, calling them a 'bunch of crooks'."
                }
            ]
        },
        {
            "title": "Chapter 2: Nelson Mandela: Long Walk to Freedom",
            "description": "Excerpts from Mandela's speech on the historic inauguration day.",
            "topics": [
                {
                    "title": "Apartheid and Freedom Fight",
                    "content": "# Nelson Mandela: Long Walk to Freedom\n\nMandela describes the inauguration ceremony of the first democratic, non-racial government in South Africa and the end of apartheid."
                },
                {
                    "title": "Concept of Courage and Freedom",
                    "content": "# Courage and Freedom\n\nMandela defines courage not as the absence of fear, but the triumph over it. He outlines the twin obligations of a man."
                }
            ]
        },
        {
            "title": "Chapter 3: Two Stories about Flying",
            "description": "His First Flight and The Black Aeroplane.",
            "topics": [
                {
                    "title": "His First Flight (Conquering Fear)",
                    "content": "# His First Flight\n\nStory of a young seagull afraid to fly. His mother lures him with a piece of fish, forcing him to take his first dive."
                },
                {
                    "title": "Black Aeroplane (Mystery Guide)",
                    "content": "# The Black Aeroplane\n\nA pilot flies through storm clouds and gets lost. A mysterious black aeroplane guides him to safety and disappears."
                }
            ]
        },
        {
            "title": "Chapter 4: From the Diary of Anne Frank",
            "description": "Insights into Anne's thoughts during life in hiding.",
            "topics": [
                {
                    "title": "Secret Annexe Life",
                    "content": "# Diary of Anne Frank\n\nAnne Frank recounts her experiences hiding from the Nazis in Amsterdam. She feels lonely despite having family."
                },
                {
                    "title": "Kitty: Anne's Sole Confidante",
                    "content": "# Anne's Diary 'Kitty'\n\nAnne treats her diary as her true friend 'Kitty' and writes down her deepest feelings and school anecdotes."
                }
            ]
        },
        {
            "title": "Chapter 5: The Hundred Dresses",
            "description": "Theme of discrimination, Wanda Petronski's story.",
            "topics": [
                {
                    "title": "Wanda Petronski and Social Discrimination",
                    "content": "# The Hundred Dresses\n\nWanda, a poor Polish girl, is teased by classmates for her name and wearing the same blue dress daily."
                },
                {
                    "title": "Empathy and Forgiveness",
                    "content": "# Apology and Reconciliation\n\nWanda wins the drawing contest with 100 designs. Maddie and Peggy feel guilty and try to make amends."
                }
            ]
        },
        {
            "title": "Chapter 6: Glimpses of India",
            "description": "Three stories showcasing cultural variations across Goa, Coorg, and Assam.",
            "topics": [
                {
                    "title": "A Baker from Goa",
                    "content": "# A Baker from Goa\n\nPortrays the traditional Goan village baker (Pader) who occupies an important place in Goan life."
                },
                {
                    "title": "Coorg & Assam Tea Gardens",
                    "content": "# Coorg and Tea from Assam\n\n- Coorg: Description of land of coffee, spices and brave people.\n- Tea from Assam: Legends surrounding the discovery and history of tea."
                }
            ]
        },
        {
            "title": "Chapter 7: Mijbil the Otter",
            "description": "The author's unusual pet, Mijbil the otter.",
            "topics": [
                {
                    "title": "Domestication of Mijbil",
                    "content": "# Mijbil the Otter\n\nMaxwell travels to Iraq and adopts an otter named Mijbil. He describes bringing Mijbil to London."
                },
                {
                    "title": "Humorous London Escapades",
                    "content": "# Mijbil in London\n\nMijbil invents games with ping-pong balls and creates panic on the plane. Londoners mistake him for baby seals."
                }
            ]
        },
        {
            "title": "Chapter 8: Madam Rides the Bus",
            "description": "Valli's first adventurous bus journey.",
            "topics": [
                {
                    "title": "Valli's Adventure and Observations",
                    "content": "# Madam Rides the Bus\n\nEight-year-old Valli plans and saves money to take a bus ride to the town. She is fascinated by the scenery."
                },
                {
                    "title": "Realisation of Life and Death",
                    "content": "# Maturity and Life's Truth\n\nOn her return journey, Valli sees a dead cow on the roadside, dampening her spirits and introducing her to the sadness of death."
                }
            ]
        },
        {
            "title": "Chapter 9: The Sermon at Benares",
            "description": "Gautama Buddha's teachings on grief and death.",
            "topics": [
                {
                    "title": "Buddha's Wisdom on Grief",
                    "content": "# The Sermon at Benares\n\nBuddha delivers his first sermon. He teaches that death is common to all, and grieving only increases pain."
                },
                {
                    "title": "Story of Kisa Gotami",
                    "content": "# Kisa Gotami's Quest\n\nKisa Gotami seeks medicine for her dead son. Buddha asks her to find mustard seeds from a house where no one has died."
                }
            ]
        },
        {
            "title": "Chapter 10: The Proposal",
            "description": "Anton Chekhov's satire on marriage for economic benefits.",
            "topics": [
                {
                    "title": "Summary of Anton Chekhov's Play",
                    "content": "# The Proposal\n\nLomov visits his neighbor Chubukov to propose to his daughter Natalia. However, they get into constant arguments."
                },
                {
                    "title": "Satire on Land and Marriage Proposals",
                    "content": "# The Arguments\n\nThey argue over ownership of Oxen Meadows and superiority of their dogs, forgetting the marriage proposal entirely."
                }
            ]
        }
    ]
}

def seed_data():
    print("[1] Logging in as teacher...")
    login_resp = requests.post(f"{BASE_URL}/api/auth/login", json=TEACHER_CREDS)
    if login_resp.status_code != 200:
        print("Login failed:", login_resp.text)
        sys.exit(1)
        
    token = login_resp.json()["data"]["token"]
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    print("Logged in successfully. Retrieving classes...")
    
    # 2. Fetch classes
    classes_resp = requests.get(f"{BASE_URL}/api/teacher/classes", headers=headers)
    if classes_resp.status_code != 200:
        print("Failed to fetch classes:", classes_resp.text)
        sys.exit(1)
        
    classes_list = classes_resp.json()["data"]["classes"]
    print(f"Found classes: {[c['class'] for c in classes_list]}")
    
    # Iterate through each class and get their courses
    for c_info in classes_list:
        class_name = c_info["class"]
        print(f"\n--- Processing class: {class_name} ---")
        
        # 3. Fetch courses
        courses_resp = requests.get(f"{BASE_URL}/api/teacher/classes/{class_name}/courses", headers=headers)
        if courses_resp.status_code != 200:
            print(f"Failed to fetch courses for class {class_name}:", courses_resp.text)
            continue
            
        courses = courses_resp.json()["data"]
        print(f"Found {len(courses)} courses in class {class_name}.")
        
        for course in courses:
            course_id = course["id"]
            course_title = course["title"]
            subject_info = course.get("subject", {})
            subject_name = subject_info.get("name", "").lower()
            
            print(f"\nCourse: '{course_title}' (ID: {course_id}), Subject: '{subject_name}'")
            
            # 4. Fetch details of this course to get existing chapters
            details_resp = requests.get(f"{BASE_URL}/api/teacher/courses/{course_id}/details", headers=headers)
            time.sleep(0.1)
            if details_resp.status_code != 200:
                print(f"Failed to fetch course details for {course_title}:", details_resp.text)
                continue
                
            details_data = details_resp.json()["data"]
            existing_chapters = details_data.get("chapters", [])
            print(f"Found {len(existing_chapters)} existing chapters. Deleting them...")
            
            # 5. Delete every existing chapter (cascades to topics)
            for chap in existing_chapters:
                chap_id = chap["id"]
                chap_title = chap["title"]
                del_resp = requests.delete(f"{BASE_URL}/api/teacher/courses/chapters/{chap_id}", headers=headers)
                time.sleep(0.1)
                if del_resp.status_code != 200:
                    print(f"Failed to delete chapter '{chap_title}' ({chap_id}):", del_resp.text)
                else:
                    print(f"Deleted chapter: '{chap_title}'")
            
            # 6. Map subject to syllabus list
            syllabus_key = None
            if "math" in subject_name:
                syllabus_key = "mathematics"
            elif "phys" in subject_name:
                syllabus_key = "physics"
            elif "chem" in subject_name:
                syllabus_key = "chemistry"
            elif "eng" in subject_name:
                syllabus_key = "english"
            
            if not syllabus_key:
                print(f"No predefined NCERT syllabus for subject '{subject_name}'. Skipping seeding.")
                continue
                
            syllabus_chapters = NCERT_SYLLABUS[syllabus_key]
            print(f"Seeding {len(syllabus_chapters)} chapters from NCERT {syllabus_key.capitalize()} syllabus...")
            
            # 7. Seed chapters & topics
            for c_idx, chap_data in enumerate(syllabus_chapters):
                create_chap_payload = {
                    "title": chap_data["title"],
                    "description": chap_data["description"],
                    "chapter_order": c_idx + 1
                }
                
                # Create chapter
                chap_resp = requests.post(
                    f"{BASE_URL}/api/teacher/courses/{course_id}/chapters",
                    headers=headers,
                    json=create_chap_payload
                )
                time.sleep(0.1)
                if chap_resp.status_code not in (200, 201):
                    print(f"Failed to create chapter '{chap_data['title']}':", chap_resp.text)
                    continue
                    
                created_chap = chap_resp.json()["data"]
                chap_id = created_chap["id"]
                print(f" -> Created Chapter {c_idx+1}: '{created_chap['title']}' (ID: {chap_id})")
                
                # Create topics
                for t_idx, topic_data in enumerate(chap_data["topics"]):
                    create_topic_payload = {
                        "title": topic_data["title"],
                        "content": topic_data["content"],
                        "topic_order": t_idx + 1
                    }
                    
                    topic_resp = requests.post(
                        f"{BASE_URL}/api/teacher/courses/chapters/{chap_id}/topics",
                        headers=headers,
                        json=create_topic_payload
                    )
                    time.sleep(0.1)
                    if topic_resp.status_code not in (200, 201):
                        print(f"    Failed to create topic '{topic_data['title']}':", topic_resp.text)
                    else:
                        created_topic = topic_resp.json()["data"]
                        print(f"    - Created Topic {t_idx+1}: '{created_topic['title']}'")

    print("\n--- COURSE SEEDING COMPLETED SUCCESSFULLY! ---")

if __name__ == "__main__":
    seed_data()
