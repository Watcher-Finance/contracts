
// SPDX-License-Identifier: MIT
// Author : Watcher-Finance
// Contract : Sentinel
// Version : 1.0.10(beta)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract Sentinel is Ownable2Step {
    // Struct to store product details
    struct Product {
        uint id; //product-id
        string name; //product-name
        address owner; //owner of product
        Rating[] ratings; //ratings given to the product
        uint64 totalAvgRating; //Total average rating of the product
        mapping(address => bool) reviewers; //Mapping of reviewer addresses to their reviewstatus
        mapping(address => Rating) reviewerRatings; // Mapping from reviewer address to their specific rating
    }

    // Struct to store individual ratings
    struct Rating {
        uint8 oneLineStatement;
        uint8 problemStatement;
        uint8 solution;
        uint8 whitepaper;
        uint8 pitchDeck;
        uint8 feedback;
        uint8 solutionBetterThanCompetitor;
        uint64 avgSubCategoryRating;
    }

    // Mapping to store products by their ID
    mapping(uint => Product) public products;

    //Decimals of 5 digits
    uint64 constant MAX_DECIMALS = 100000;

    // List of authorised users
    mapping(address => bool) public authorizedUsers;

    // Event to be emitted when a product is registered
    event ProductRegistered(
        uint indexed id,
        string name,
        address indexed owner
    );

    // Event to be emitted when a product is reviewed
    event ProductReviewed(
        uint indexed id,
        Rating rating,
        uint totalAvgRating,
        address indexed reviewer
    );

    // Event to be emitted when an authorized user is added
    event UserAuthorized(address indexed user);

    // Event to be emitted when an authorized user is removed
    event UserDeAuthorized(address indexed user);

    // Counter for product IDs
    uint private productCounter;

    // Constructor to initialize the owner
    constructor() Ownable2Step() {}

    // Modifier to check if the caller is an authorized user
    modifier onlyAuthorizedUser() {
        require(authorizedUsers[msg.sender], "Not an authorized user");
        _;
    }

    /**
     * @dev Adds a new authorized user.
     * @param user Address of user to authorized .
     */
    function addAuthorizedUser(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(!authorizedUsers[user], "User is already authorized");
        authorizedUsers[user] = true;
        emit UserAuthorized(user);
    }

    /**
     * @dev Removes an authorized user.
     * @param user Address of user to deauthorized .
     */
    function removeAuthorizedUser(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(authorizedUsers[user], "User is not authorized");
        authorizedUsers[user] = false;
        emit UserDeAuthorized(user);
    }

    /**
     * @dev Registers a new product.
     * @param name The name of the product to be registered.
     * @param productOwner The address of the product owner.
     */
    function registerProduct(
        string memory name,
        address productOwner
    ) external onlyAuthorizedUser {
        require(bytes(name).length > 0, "Product name cannot be empty");
        require(productOwner != address(0), "Invalid product owner address");

        productCounter++;
        Product storage newProduct = products[productCounter];
        newProduct.id = productCounter;
        newProduct.name = name;
        newProduct.owner = productOwner;
        newProduct.totalAvgRating = 0;

        emit ProductRegistered(productCounter, name, productOwner);
    }

    /**
     * @dev Reviews a product.
     * @param productId The ID of the product to be reviewed.
     * @param ratings The array of ratings for the subcategories.
     * @param reviewer The address of the reviewer.
     */
    function reviewProduct(
        uint productId,
        uint8[7] memory ratings,
        address reviewer
    ) external onlyAuthorizedUser {
        require(products[productId].id != 0, "Product does not exist");
        require(
            !products[productId].reviewers[reviewer],
            "Reviewer has already reviewed this product"
        );

        for (uint8 i = 0; i < ratings.length; i++) {
            require(
                ratings[i] > 0 && ratings[i] <= 5,
                "Each rating should be between 1 and 5"
            );
        }

        Rating memory newRating = Rating({
            oneLineStatement: ratings[0],
            problemStatement: ratings[1],
            solution: ratings[2],
            whitepaper: ratings[3],
            pitchDeck: ratings[4],
            feedback: ratings[5],
            solutionBetterThanCompetitor: ratings[6],
            avgSubCategoryRating: calculateAvgSubCategoryRating(ratings)
        });

        Product storage product = products[productId];
        product.ratings.push(newRating);
        product.reviewerRatings[reviewer] = newRating;
        product.reviewers[reviewer] = true;
        product.totalAvgRating = calculateTotalAvgRating(product.ratings);

        emit ProductReviewed(
            productId,
            newRating,
            products[productId].totalAvgRating,
            reviewer
        );
    }

    /**
     * @dev Calculates the average subcategory rating.
     * @param ratings The array of subcategory ratings.
     * @return The average subcategory rating scaled by MAX_DECIMALS.
     */
    function calculateAvgSubCategoryRating(
        uint8[7] memory ratings
    ) internal pure returns (uint64) {
        uint16 sum = 0;
        for (uint8 i = 0; i < 7; i++) {
            sum += ratings[i];
        }
        return (uint64(sum) * MAX_DECIMALS) / 7;
    }

    /**
     * @dev Calculates the total average rating of a product.
     * @param ratingsArray The array of ratings for the product.
     * @return The total average rating of the product.
     */
    function calculateTotalAvgRating(
        Rating[] memory ratingsArray
    ) internal pure returns (uint64) {
        uint totalRatings = ratingsArray.length;
        uint64 sum = 0;

        for (uint i = 0; i < totalRatings; i++) {
            sum += ratingsArray[i].avgSubCategoryRating;
        }

        return totalRatings > 0 ? sum / uint64(totalRatings) : 0;
    }

    /**
     * @dev Retrieves product details.
     * @param productId The ID of the product to retrieve.
     * @return id The product ID.
     * @return name The product name.
     * @return owner The product owner address.
     * @return ratings The array of ratings for the product.
     * @return totalAvgRating The total average rating of the product.
     */
    function getProduct(
        uint productId
    )
        public
        view
        returns (uint, string memory, address, Rating[] memory, uint)
    {
        require(products[productId].id != 0, "Product does not exist");
        Product storage product = products[productId];
        return (
            product.id,
            product.name,
            product.owner,
            product.ratings,
            product.totalAvgRating
        );
    }

    /**
     * @dev Retrieves a review by product ID and reviewer address.
     * @param productId The ID of the product.
     * @param reviewer The address of the reviewer.
     * @return The rating given by the reviewer.
     */
    function getReview(
        uint productId,
        address reviewer
    ) public view returns (Rating memory) {
        require(products[productId].id != 0, "Product does not exist");
        require(
            products[productId].reviewers[reviewer],
            "Reviewer has not reviewed this product"
        );
        return products[productId].reviewerRatings[reviewer];
    }
}
