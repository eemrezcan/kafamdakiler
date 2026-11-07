using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class AddIsrarVeProjeRepo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "Acil",
                table: "Hatirlaticilar",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "IsrarAraligiDakika",
                table: "Hatirlaticilar",
                type: "integer",
                nullable: false,
                defaultValue: 15);

            migrationBuilder.AddColumn<int>(
                name: "IsrarEnCok",
                table: "Hatirlaticilar",
                type: "integer",
                nullable: false,
                defaultValue: 3);

            migrationBuilder.AddColumn<bool>(
                name: "Israrli",
                table: "Hatirlaticilar",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "ProjeRepolari",
                columns: table => new
                {
                    ProjeKimligi = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Depo = table.Column<string>(type: "character varying(140)", maxLength: 140, nullable: false),
                    GuncellendiAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProjeRepolari", x => x.ProjeKimligi);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ProjeRepolari");

            migrationBuilder.DropColumn(
                name: "Acil",
                table: "Hatirlaticilar");

            migrationBuilder.DropColumn(
                name: "IsrarAraligiDakika",
                table: "Hatirlaticilar");

            migrationBuilder.DropColumn(
                name: "IsrarEnCok",
                table: "Hatirlaticilar");

            migrationBuilder.DropColumn(
                name: "Israrli",
                table: "Hatirlaticilar");
        }
    }
}
